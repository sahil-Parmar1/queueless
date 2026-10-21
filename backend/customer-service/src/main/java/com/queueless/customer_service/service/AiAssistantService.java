package com.queueless.customer_service.service;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.time.LocalTime;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.queueless.customer_service.model.OfficeCategory;
import com.queueless.customer_service.model.OfficeProfile;
import com.queueless.customer_service.model.TokenStatus;
import com.queueless.customer_service.model.VerificationStatus;
import com.queueless.customer_service.repository.OfficeProfileRepository;
import com.queueless.customer_service.repository.QueueTokenRepository;

@Service
public class AiAssistantService {

    private final CustomerQueueService customerQueueService;
    private final OfficeProfileRepository officeProfileRepository;
    private final QueueTokenRepository queueTokenRepository;
    private final ObjectMapper objectMapper;
    private final HttpClient httpClient;

    @Value("${gemini.api.key:}")
    private String geminiApiKey;

    public AiAssistantService(
            CustomerQueueService customerQueueService,
            OfficeProfileRepository officeProfileRepository,
            QueueTokenRepository queueTokenRepository) {
        this.customerQueueService = customerQueueService;
        this.officeProfileRepository = officeProfileRepository;
        this.queueTokenRepository = queueTokenRepository;
        this.objectMapper = new ObjectMapper();
        this.httpClient = HttpClient.newBuilder()
                .connectTimeout(Duration.ofSeconds(10))
                .build();
    }

    public Map<String, Object> processChat(
            Long customerId,
            String customerEmail,
            String message,
            List<Map<String, String>> history) {

        String prompt = message != null ? message.trim() : "";

        // 1. Fetch user active token data
        Map<String, Object> activeTokenData = customerQueueService.getMyActiveToken(null, customerId, customerEmail);
        boolean hasActiveToken = Boolean.TRUE.equals(activeTokenData.get("hasActiveToken"));

        // 2. Fetch all approved offices & their live waiting queue
        List<OfficeProfile> offices = officeProfileRepository.findByVerificationStatus(VerificationStatus.APPROVED);
        List<Map<String, Object>> liveOfficeStats = new ArrayList<>();
        for (OfficeProfile op : offices) {
            long waitingCount = queueTokenRepository.countByOfficeIdAndStatus(op.getId(), TokenStatus.WAITING);
            int avgMin = op.getCategory() == OfficeCategory.SALON ? 20 : 12;
            int estWait = (int) (waitingCount * avgMin);

            Map<String, Object> stat = new HashMap<>();
            stat.put("id", op.getId());
            stat.put("name", op.getUser() != null ? op.getUser().getName() : "Office");
            stat.put("category", op.getCategory() != null ? op.getCategory().name() : "OFFICE");
            stat.put("isOpen", Boolean.TRUE.equals(op.getIsOpen()));
            stat.put("waitingCount", waitingCount);
            stat.put("estWaitMinutes", estWait);
            stat.put("address", op.getAddress());
            stat.put("city", op.getCity());
            stat.put("doctorName", op.getDoctorName());
            stat.put("specialization", op.getSpecialization());
            stat.put("latitude", op.getLatitude());
            stat.put("longitude", op.getLongitude());
            liveOfficeStats.add(stat);
        }

        // 3. Try Google Gemini API if configured
        String effectiveApiKey = geminiApiKey != null && !geminiApiKey.isBlank()
                ? geminiApiKey.trim()
                : System.getenv("GEMINI_API_KEY");

        if (effectiveApiKey != null && !effectiveApiKey.isBlank()) {
            try {
                Map<String, Object> geminiRes = callGeminiApi(effectiveApiKey, prompt, activeTokenData, liveOfficeStats, history);
                if (geminiRes != null && geminiRes.get("reply") != null) {
                    return geminiRes;
                }
            } catch (Exception e) {
                System.err.println("Gemini API call failed, falling back to intelligent rule engine: " + e.getMessage());
            }
        }

        // 4. Intelligent Built-in Queueless Context Engine
        return generateRuleEngineResponse(prompt, activeTokenData, hasActiveToken, liveOfficeStats);
    }

    private Map<String, Object> generateRuleEngineResponse(
            String prompt,
            Map<String, Object> activeToken,
            boolean hasActiveToken,
            List<Map<String, Object>> liveOffices) {

        String lower = prompt.toLowerCase();
        Map<String, Object> response = new HashMap<>();
        List<Map<String, Object>> suggestedActions = new ArrayList<>();
        List<String> quickReplies = new ArrayList<>();

        // Intent: Lunch / Food / Coffee / Time Left
        if (lower.contains("lunch") || lower.contains("food") || lower.contains("eat") || lower.contains("coffee") || lower.contains("tea") || lower.contains("break")) {
            if (hasActiveToken) {
                int waitMins = getInt(activeToken.get("estimatedWaitMinutes"), 15);
                int ahead = getInt(activeToken.get("peopleAhead"), 0);
                String tokenNum = String.valueOf(activeToken.get("tokenNumber"));
                String officeName = String.valueOf(activeToken.get("officeName"));

                LocalTime estCallTime = LocalTime.now().plusMinutes(waitMins);
                String timeStr = estCallTime.format(DateTimeFormatter.ofPattern("h:mm a"));

                if (waitMins >= 25) {
                    response.put("reply", "🍽️ **Yes, you have time for a quick meal or coffee!**\n\n" +
                            "• **Your Token:** #" + tokenNum + " at **" + officeName + "**\n" +
                            "• **Estimated Wait:** ~" + waitMins + " mins (" + ahead + " people ahead)\n" +
                            "• **Estimated Call Time:** Around **" + timeStr + "**\n\n" +
                            "💡 *Tip: We recommend heading back 5-10 minutes before your estimated call time so you don't miss your turn!*");
                } else if (waitMins >= 12) {
                    response.put("reply", "☕ **You have time for a quick coffee nearby!**\n\n" +
                            "• **Your Token:** #" + tokenNum + " at **" + officeName + "**\n" +
                            "• **Estimated Wait:** ~" + waitMins + " mins (" + ahead + " people ahead)\n" +
                            "• **Estimated Call Time:** Around **" + timeStr + "**\n\n" +
                            "⚠️ *Keep it quick and stay within walking distance of the office.*");
                } else {
                    response.put("reply", "⚡ **Better stay close! Your turn is coming up soon.**\n\n" +
                            "• **Your Token:** #" + tokenNum + " at **" + officeName + "**\n" +
                            "• **Estimated Wait:** ~" + waitMins + " mins (" + ahead + " people ahead)\n\n" +
                            "Grabbing a meal right now might cause you to miss your turn. Please wait in the lounge or nearby.");
                }

                suggestedActions.add(createAction("VIEW_TOKEN", "View Live Token #" + tokenNum, activeToken));
                if (activeToken.get("officeAddress") != null) {
                    suggestedActions.add(createAction("OPEN_MAP", "Get Directions", activeToken));
                }
            } else {
                response.put("reply", "You don't currently have any active queue token. Feel free to enjoy your meal!\n\nWould you like to browse open clinics or salons to book a token?");
                suggestedActions.add(createAction("SEARCH_OFFICES", "Browse Offices", Map.of()));
            }

            quickReplies.add("How many people ahead?");
            quickReplies.add("Shortest wait clinic right now");
            quickReplies.add("How does priority queue work?");

        // Intent: People ahead / Wait time / Token Status
        } else if (lower.contains("people ahead") || lower.contains("how many") || lower.contains("how long") || lower.contains("wait time") || lower.contains("turn") || lower.contains("my token") || lower.contains("status")) {
            if (hasActiveToken) {
                int waitMins = getInt(activeToken.get("estimatedWaitMinutes"), 15);
                int ahead = getInt(activeToken.get("peopleAhead"), 0);
                String tokenNum = String.valueOf(activeToken.get("tokenNumber"));
                String officeName = String.valueOf(activeToken.get("officeName"));
                String status = String.valueOf(activeToken.get("status"));
                boolean isPriority = Boolean.TRUE.equals(activeToken.get("isPriority"));

                LocalTime estCallTime = LocalTime.now().plusMinutes(waitMins);
                String timeStr = estCallTime.format(DateTimeFormatter.ofPattern("h:mm a"));

                response.put("reply", "🎫 **Live Token Status for #" + tokenNum + "**\n\n" +
                        "• **Office:** " + officeName + "\n" +
                        "• **Status:** " + status + (isPriority ? " *(High Priority Approved)*" : "") + "\n" +
                        "• **People Ahead:** **" + ahead + "** " + (ahead == 1 ? "person" : "people") + "\n" +
                        "• **Estimated Wait:** **~" + waitMins + " minutes**\n" +
                        "• **Estimated Call Time:** ~" + timeStr + "\n\n" +
                        "We'll notify you automatically when you are next in line!");

                suggestedActions.add(createAction("VIEW_TOKEN", "View Digital Token", activeToken));
                suggestedActions.add(createAction("OPEN_MAP", "Directions to " + officeName, activeToken));
            } else {
                response.put("reply", "You don't have any active waiting token right now.\n\nYou can search for a clinic or salon, check their live crowd status, and book a digital token instantly without waiting in line!");
                suggestedActions.add(createAction("SEARCH_OFFICES", "Find Offices & Clinics", Map.of()));
            }

            quickReplies.add("Do I have time for lunch?");
            quickReplies.add("Least crowded clinic right now");
            quickReplies.add("Directions to clinic");

        // Intent: Shortest wait / Least crowded / Best clinic
        } else if (lower.contains("shortest") || lower.contains("least crowded") || lower.contains("quickest") || lower.contains("crowd") || lower.contains("fastest") || lower.contains("rush")) {
            liveOffices.sort(Comparator.comparingInt(m -> (int) m.get("waitingCount")));

            StringBuilder sb = new StringBuilder("🏥 **Live Queue & Crowd Comparison:**\n\n");
            int rank = 1;
            for (Map<String, Object> op : liveOffices) {
                if (rank > 4) break;
                boolean open = Boolean.TRUE.equals(op.get("isOpen"));
                int wait = (int) op.get("waitingCount");
                int est = (int) op.get("estWaitMinutes");
                String name = (String) op.get("name");
                String cat = (String) op.get("category");

                sb.append(rank).append(". **").append(name).append("** (").append(cat).append(")\n");
                sb.append("   • Status: ").append(open ? "🟢 **OPEN**" : "🔴 Closed").append("\n");
                sb.append("   • In Queue: **").append(wait).append(" waiting** (~").append(est).append(" mins wait)\n\n");

                if (rank == 1) {
                    suggestedActions.add(createAction("BOOK_TOKEN", "Book at " + name, op));
                }
                rank++;
            }

            sb.append("💡 *Tip: You can generate a token before leaving home so you arrive right when your number is called!*");
            response.put("reply", sb.toString());

            quickReplies.add("Do I have time for lunch?");
            quickReplies.add("How does priority token work?");
            quickReplies.add("Find a dentist");

        // Intent: Dentist / Dental / Tooth / Salon / Hair / Fever / Doctor
        } else if (lower.contains("tooth") || lower.contains("dentist") || lower.contains("dental") || lower.contains("teeth")) {
            response.put("reply", "🦷 **Dental Care Recommendation:**\n\n" +
                    "For dental pain, toothaches, or cleanings, we recommend visiting a verified Dental Clinic.\n\n" +
                    "Check the Dental category on the home screen to see currently open dentists with real-time queue wait times.");
            suggestedActions.add(createAction("SEARCH_CATEGORY", "Browse Dental Clinics", Map.of("category", "CLINIC")));
            quickReplies.add("Shortest wait clinic right now");
            quickReplies.add("How does priority token work?");

        } else if (lower.contains("hair") || lower.contains("haircut") || lower.contains("beard") || lower.contains("salon") || lower.contains("shave") || lower.contains("facial")) {
            response.put("reply", "💈 **Salon & Grooming Recommendation:**\n\n" +
                    "For haircuts, styling, and grooming services, look for our verified salons like **Sahil Parmar Unisex Salon**.\n\n" +
                    "You can view their waiting queue live and book a token before heading over to avoid waiting on the sofa!");
            suggestedActions.add(createAction("SEARCH_CATEGORY", "Browse Salons", Map.of("category", "SALON")));
            quickReplies.add("Shortest wait clinic right now");
            quickReplies.add("Do I have time for lunch?");

        // Intent: Priority Request / Emergency / Elderly / Pregnant
        } else if (lower.contains("priority") || lower.contains("urgent") || lower.contains("emergency") || lower.contains("pregnant") || lower.contains("elderly") || lower.contains("disabled")) {
            response.put("reply", "⭐ **Queueless Priority Token Policy:**\n\n" +
                    "Customers with special needs can request **High Priority** service:\n" +
                    "• Medical emergencies & acute pain\n" +
                    "• Senior citizens (60+)\n" +
                    "• Expecting mothers / pregnancy\n" +
                    "• Persons with disabilities\n\n" +
                    "📌 **How to request:**\n" +
                    "1. Book a standard token.\n" +
                    "2. On your Digital Token screen, tap **'Request Priority'**.\n" +
                    "3. Enter a brief reason. The office staff or doctor will review and approve it immediately.");

            if (hasActiveToken) {
                suggestedActions.add(createAction("VIEW_TOKEN", "Open Token to Request Priority", activeToken));
            }
            quickReplies.add("How long until my token is called?");
            quickReplies.add("Shortest wait clinic right now");

        // Intent: Directions / Map / Location
        } else if (lower.contains("where") || lower.contains("direction") || lower.contains("map") || lower.contains("address") || lower.contains("reach")) {
            if (hasActiveToken && activeToken.get("officeName") != null) {
                String name = String.valueOf(activeToken.get("officeName"));
                String addr = String.valueOf(activeToken.get("officeAddress"));
                response.put("reply", "📍 **Location for " + name + ":**\n\n" +
                        "• **Address:** " + addr + "\n\n" +
                        "Tap the button below to open Google Maps with turn-by-turn navigation directly to the clinic entrance!");
                suggestedActions.add(createAction("OPEN_MAP", "Open Directions in Maps", activeToken));
                suggestedActions.add(createAction("VIEW_TOKEN", "View Active Token", activeToken));
            } else {
                response.put("reply", "You don't have an active token right now. You can find all nearby clinics and offices on the interactive map on your home screen!");
                suggestedActions.add(createAction("SEARCH_OFFICES", "Find Offices on Map", Map.of()));
            }
            quickReplies.add("How many people ahead?");
            quickReplies.add("Shortest wait clinic right now");

        // Default: Welcome & General Assistant
        } else {
            if (hasActiveToken) {
                String tokenNum = String.valueOf(activeToken.get("tokenNumber"));
                String officeName = String.valueOf(activeToken.get("officeName"));
                int ahead = getInt(activeToken.get("peopleAhead"), 0);
                int waitMins = getInt(activeToken.get("estimatedWaitMinutes"), 15);

                response.put("reply", "👋 **Hello! I'm your Queueless AI Assistant.**\n\n" +
                        "You currently have token **#" + tokenNum + "** at **" + officeName + "** with **" + ahead + " people ahead** (~" + waitMins + " mins wait).\n\n" +
                        "Feel free to ask me questions like:\n" +
                        "• *\"Do I have time to eat lunch?\"*\n" +
                        "• *\"How long until my turn?\"*\n" +
                        "• *\"Directions to my clinic\"*\n" +
                        "• *\"Which clinic has the shortest wait?\"*");

                suggestedActions.add(createAction("VIEW_TOKEN", "View Token #" + tokenNum, activeToken));
            } else {
                response.put("reply", "👋 **Hello! I'm your Queueless AI Assistant.**\n\n" +
                        "I can help you skip the physical waiting room and manage your queue tokens with ease:\n\n" +
                        "• ⏱️ **Predict wait times** & tell you if you have time for coffee/lunch\n" +
                        "• 🏥 **Compare live queues** to find clinics with the shortest lines\n" +
                        "• ⭐ **Explain Priority queue** requests & app features\n" +
                        "• 🗺️ **Provide directions** to clinics and salons");

                suggestedActions.add(createAction("SEARCH_OFFICES", "Find Clinics & Salons", Map.of()));
            }

            quickReplies.add("How long until my turn?");
            quickReplies.add("Do I have time for lunch?");
            quickReplies.add("Shortest wait clinic right now");
            quickReplies.add("How does priority queue work?");
        }

        response.put("suggestedActions", suggestedActions);
        response.put("quickReplies", quickReplies);
        return response;
    }

    private Map<String, Object> callGeminiApi(
            String apiKey,
            String prompt,
            Map<String, Object> activeToken,
            List<Map<String, Object>> liveOffices,
            List<Map<String, String>> history) throws Exception {

        String url = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=" + apiKey;

        String systemInstruction = "You are Queueless AI Assistant, an empathetic, concise queue concierge for the Queueless mobile app. " +
                "You have access to live user active token and real-time office waiting queues. " +
                "Always format your answers in clean Markdown with bold headers and bullet points. " +
                "Keep responses concise (2-4 paragraphs max). " +
                "Here is the user's active token data: " + objectMapper.writeValueAsString(activeToken) + ". " +
                "Here are the live offices: " + objectMapper.writeValueAsString(liveOffices) + ".";

        Map<String, Object> requestBody = new HashMap<>();
        Map<String, Object> systemPart = Map.of("parts", List.of(Map.of("text", systemInstruction)));
        requestBody.put("systemInstruction", systemPart);

        List<Map<String, Object>> contents = new ArrayList<>();
        if (history != null) {
            for (Map<String, String> h : history) {
                String role = "user".equalsIgnoreCase(h.get("role")) ? "user" : "model";
                String txt = h.get("text");
                if (txt != null && !txt.isBlank()) {
                    contents.add(Map.of("role", role, "parts", List.of(Map.of("text", txt))));
                }
            }
        }
        contents.add(Map.of("role", "user", "parts", List.of(Map.of("text", prompt))));
        requestBody.put("contents", contents);

        String jsonBody = objectMapper.writeValueAsString(requestBody);

        HttpRequest request = HttpRequest.newBuilder()
                .uri(URI.create(url))
                .header("Content-Type", "application/json")
                .timeout(Duration.ofSeconds(15))
                .POST(HttpRequest.BodyPublishers.ofString(jsonBody))
                .build();

        HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());
        if (response.statusCode() == 200) {
            JsonNode root = objectMapper.readTree(response.body());
            JsonNode candidates = root.path("candidates");
            if (candidates.isArray() && candidates.size() > 0) {
                JsonNode parts = candidates.get(0).path("content").path("parts");
                if (parts.isArray() && parts.size() > 0) {
                    String replyText = parts.get(0).path("text").asText();
                    Map<String, Object> result = new HashMap<>();
                    result.put("reply", replyText);

                    List<Map<String, Object>> actions = new ArrayList<>();
                    if (Boolean.TRUE.equals(activeToken.get("hasActiveToken"))) {
                        actions.add(createAction("VIEW_TOKEN", "View Digital Token", activeToken));
                        if (activeToken.get("officeAddress") != null) {
                            actions.add(createAction("OPEN_MAP", "Get Directions", activeToken));
                        }
                    } else {
                        actions.add(createAction("SEARCH_OFFICES", "Find Offices & Clinics", Map.of()));
                    }
                    result.put("suggestedActions", actions);
                    result.put("quickReplies", List.of(
                            "How long until my turn?",
                            "Do I have time for lunch?",
                            "Shortest wait clinic right now"
                    ));
                    return result;
                }
            }
        }
        return null;
    }

    private Map<String, Object> createAction(String type, String label, Map<String, Object> data) {
        Map<String, Object> action = new HashMap<>();
        action.put("type", type);
        action.put("label", label);
        action.put("data", data);
        return action;
    }

    private int getInt(Object val, int defaultVal) {
        if (val instanceof Number n) return n.intValue();
        if (val != null) {
            try {
                return Integer.parseInt(val.toString());
            } catch (Exception ignored) {}
        }
        return defaultVal;
    }
}
