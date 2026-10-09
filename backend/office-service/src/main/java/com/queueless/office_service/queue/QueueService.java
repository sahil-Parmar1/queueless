package com.queueless.office_service.queue;

import java.time.Duration;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.queueless.office_service.provider.Provider;
import com.queueless.office_service.provider.ProviderRepository;
import com.queueless.office_service.provider.ProviderService;
import com.queueless.office_service.user.OfficeProfile;
import com.queueless.office_service.user.OfficeProfileRepository;

@Service
@Transactional
public class QueueService {

    private final QueueTokenRepository tokenRepository;
    private final OfficeProfileRepository officeProfileRepository;
    private final ProviderRepository providerRepository;
    private final ProviderService providerService;

    private static final int DEFAULT_SERVICE_TIME_MINUTES = 12;

    public QueueService(
            QueueTokenRepository tokenRepository,
            OfficeProfileRepository officeProfileRepository,
            ProviderRepository providerRepository,
            ProviderService providerService) {
        this.tokenRepository = tokenRepository;
        this.officeProfileRepository = officeProfileRepository;
        this.providerRepository = providerRepository;
        this.providerService = providerService;
    }

    /**
     * Book a new token for an office without specific provider.
     */
    public Map<String, Object> bookToken(
            Long officeId,
            Long customerId,
            String customerName,
            String customerPhone,
            String customerEmail) {
        return bookToken(officeId, null, customerId, customerName, customerPhone, customerEmail);
    }

    public Map<String, Object> bookToken(
            Long officeId,
            Long providerId,
            Long customerId,
            String customerName,
            String customerPhone,
            String customerEmail) {
        return bookToken(officeId, providerId, customerId, customerName, customerPhone, customerEmail, null);
    }

    /**
     * Book a new token for an office with optional provider assignment, task description and availability validation.
     */
    public Map<String, Object> bookToken(
            Long officeId,
            Long providerId,
            Long customerId,
            String customerName,
            String customerPhone,
            String customerEmail,
            String taskDescription) {

        // 1. Acquire pessimistic write lock on the office row to serialize all token generation requests for this office
        OfficeProfile office = officeProfileRepository.findByIdForUpdate(officeId)
                .orElseThrow(() -> new IllegalArgumentException("Office not found with id: " + officeId));

        LocalDate today = LocalDate.now();
        LocalDateTime startOfDay = today.atStartOfDay();
        LocalDateTime endOfDay = today.atTime(LocalTime.MAX);

        // 2. Enforce Office Daily Maximum Token Limit
        long officeTokensToday = tokenRepository.countValidTokensTodayByOffice(officeId, startOfDay, endOfDay);
        int officeDailyMax = office.getDailyMaxTokens();
        if (officeTokensToday >= officeDailyMax) {
            throw new IllegalStateException("Office has reached its daily maximum limit of " + officeDailyMax + " tokens for today.");
        }

        // 3. Provider validation and Provider Daily Maximum Limit
        Provider provider = null;
        if (providerId != null) {
            provider = providerRepository.findByIdAndOfficeId(providerId, officeId)
                    .orElseThrow(() -> new IllegalArgumentException("Provider not found or does not belong to this office"));

            if (!providerService.isProviderAvailableNow(provider)) {
                throw new IllegalStateException("Provider is currently unavailable");
            }

            if (provider.getDailyMaxTokens() != null) {
                long providerTokensToday = tokenRepository.countValidTokensTodayByProvider(providerId, startOfDay, endOfDay);
                int providerDailyMax = provider.getDailyMaxTokens();
                if (providerTokensToday >= providerDailyMax) {
                    throw new IllegalStateException("Provider " + provider.getName() + " has reached their daily maximum limit of " + providerDailyMax + " tokens for today.");
                }
            }
        }

        Integer maxSeq = tokenRepository.findMaxSequenceNumberToday(officeId, startOfDay);
        int nextSeq = (maxSeq == null ? 0 : maxSeq) + 1;

        String prefix = "A-";
        if (office.getCategory() != null) {
            prefix = office.getCategory().name().substring(0, 1) + "-";
        }
        String tokenNumber = prefix + String.format("%03d", nextSeq);

        Long currentWaiting = tokenRepository.countByOfficeIdAndStatus(officeId, TokenStatus.WAITING);
        int waitTime = (int) (currentWaiting * DEFAULT_SERVICE_TIME_MINUTES);

        QueueToken token = new QueueToken();
        token.setOffice(office);
        token.setProvider(provider);
        token.setSequenceNumber(nextSeq);
        token.setTokenNumber(tokenNumber);
        token.setCustomerId(customerId);
        token.setCustomerName(customerName != null && !customerName.isBlank() ? customerName.trim() : "Customer");
        token.setCustomerPhone(customerPhone);
        token.setCustomerEmail(customerEmail);
        token.setStatus(TokenStatus.WAITING);
        token.setEstimatedWaitMinutes(waitTime);
        token.setBookedAt(LocalDateTime.now());
        if (taskDescription != null && !taskDescription.isBlank()) {
            String trimmed = taskDescription.trim();
            token.setTaskDescription(trimmed.length() > 25 ? trimmed.substring(0, 25) : trimmed);
        }

        QueueToken saved = tokenRepository.save(token);

        Map<String, Object> response = new HashMap<>();
        response.put("token", saved);
        response.put("tokenNumber", saved.getTokenNumber());
        response.put("sequenceNumber", saved.getSequenceNumber());
        response.put("peopleAhead", currentWaiting);
        response.put("estimatedWaitMinutes", waitTime);
        response.put("officeId", office.getId());
        response.put("officeName", office.getUser() != null ? office.getUser().getName() : "Office");
        response.put("category", office.getCategory() != null ? office.getCategory().name() : "OFFICE");
        response.put("status", saved.getStatus().name());
        response.put("taskDescription", saved.getTaskDescription());
        if (provider != null) {
            response.put("providerId", provider.getId());
            response.put("providerName", provider.getName());
            response.put("providerDesignation", provider.getDesignation());
        }

        return response;
    }

    /**
     * Get live queue status for an office.
     */
    @Transactional(readOnly = true)
    public Map<String, Object> getLiveQueue(Long officeId) {
        OfficeProfile office = officeProfileRepository.findById(officeId)
                .orElseThrow(() -> new RuntimeException("Office not found: " + officeId));

        // Serving token is CALLED or IN_SERVICE
        QueueToken activeToken = tokenRepository
                .findFirstByOfficeIdAndStatusInOrderBySequenceNumberAsc(
                        officeId,
                        List.of(TokenStatus.IN_SERVICE, TokenStatus.CALLED)
                ).orElse(null);

        Long waitingCount = tokenRepository.countByOfficeIdAndStatus(officeId, TokenStatus.WAITING);

        LocalDateTime startOfDay = LocalDateTime.of(LocalDate.now(), LocalTime.MIN);
        LocalDateTime endOfDay = LocalDateTime.of(LocalDate.now(), LocalTime.MAX);
        List<QueueToken> todayTokens = tokenRepository.findByOfficeIdAndBookedAtBetweenOrderBySequenceNumberAsc(
                officeId, startOfDay, endOfDay
        );

        long completedCount = todayTokens.stream()
                .filter(t -> t.getStatus() == TokenStatus.COMPLETED)
                .count();

        // Next waiting tokens (up to 5)
        List<QueueToken> waitingTokens = tokenRepository
                .findByOfficeIdAndStatusInOrderBySequenceNumberAsc(officeId, List.of(TokenStatus.WAITING));

        List<Map<String, Object>> nextTokens = new ArrayList<>();
        for (int i = 0; i < Math.min(5, waitingTokens.size()); i++) {
            QueueToken t = waitingTokens.get(i);
            nextTokens.add(Map.of(
                    "tokenNumber", t.getTokenNumber(),
                    "customerName", maskName(t.getCustomerName()),
                    "sequenceNumber", t.getSequenceNumber(),
                    "position", i + 1
            ));
        }

        // Unassigned tokens (where provider == null and status is WAITING)
        List<QueueToken> unassignedTokens = tokenRepository
                .findByOfficeIdAndProviderIsNullAndStatusInOrderBySequenceNumberAsc(
                        officeId, List.of(TokenStatus.WAITING)
                );

        List<Map<String, Object>> unassignedList = new ArrayList<>();
        for (int i = 0; i < unassignedTokens.size(); i++) {
            QueueToken t = unassignedTokens.get(i);
            Map<String, Object> item = new HashMap<>();
            item.put("id", t.getId());
            item.put("tokenNumber", t.getTokenNumber());
            item.put("customerName", t.getCustomerName());
            item.put("customerPhone", t.getCustomerPhone() != null ? t.getCustomerPhone() : "");
            item.put("customerEmail", t.getCustomerEmail() != null ? t.getCustomerEmail() : "");
            item.put("sequenceNumber", t.getSequenceNumber());
            item.put("status", t.getStatus().name());
            item.put("estimatedWaitMinutes", t.getEstimatedWaitMinutes());
            item.put("position", i + 1);
            item.put("bookedAt", t.getBookedAt() != null ? t.getBookedAt().toString() : "");
            item.put("requestedProviderId", t.getRequestedProvider() != null ? t.getRequestedProvider().getId() : null);
            item.put("requestedProviderName", t.getRequestedProvider() != null ? t.getRequestedProvider().getName() : null);
            item.put("requestStatus", t.getRequestStatus() != null ? t.getRequestStatus() : "NONE");
            item.put("taskDescription", t.getTaskDescription() != null ? t.getTaskDescription() : "");
            unassignedList.add(item);
        }

        // All waiting tokens for this office (with assigned provider details)
        List<Map<String, Object>> allWaitingList = new ArrayList<>();
        for (int i = 0; i < waitingTokens.size(); i++) {
            QueueToken t = waitingTokens.get(i);
            Map<String, Object> item = new HashMap<>();
            item.put("id", t.getId());
            item.put("tokenNumber", t.getTokenNumber());
            item.put("customerName", t.getCustomerName());
            item.put("customerPhone", t.getCustomerPhone() != null ? t.getCustomerPhone() : "");
            item.put("sequenceNumber", t.getSequenceNumber());
            item.put("status", t.getStatus().name());
            item.put("estimatedWaitMinutes", t.getEstimatedWaitMinutes());
            item.put("position", i + 1);
            item.put("bookedAt", t.getBookedAt() != null ? t.getBookedAt().toString() : "");
            item.put("taskDescription", t.getTaskDescription() != null ? t.getTaskDescription() : "");
            item.put("isPriority", Boolean.TRUE.equals(t.getIsPriority()));
            item.put("priorityStatus", t.getPriorityStatus() != null ? t.getPriorityStatus() : "NONE");
            item.put("priorityReason", t.getPriorityReason() != null ? t.getPriorityReason() : "");
            if (t.getProvider() != null) {
                item.put("providerId", t.getProvider().getId());
                item.put("providerName", t.getProvider().getName());
                item.put("providerDesignation", t.getProvider().getDesignation());
            } else {
                item.put("providerId", null);
                item.put("providerName", "Unassigned");
                item.put("providerDesignation", "Desk Counter");
            }
            allWaitingList.add(item);
        }

        // Pending Priority Requests from customers waiting for Office review
        List<QueueToken> pendingPriorityTokens = tokenRepository.findByOfficeIdAndPriorityStatusAndStatusInOrderByPriorityRequestedAtAsc(
                officeId, "PENDING_OFFICE", List.of(TokenStatus.WAITING)
        );

        List<Map<String, Object>> priorityRequestList = new ArrayList<>();
        for (QueueToken pt : pendingPriorityTokens) {
            Map<String, Object> item = new HashMap<>();
            item.put("id", pt.getId());
            item.put("tokenNumber", pt.getTokenNumber());
            item.put("customerName", pt.getCustomerName());
            item.put("customerPhone", pt.getCustomerPhone() != null ? pt.getCustomerPhone() : "");
            item.put("customerEmail", pt.getCustomerEmail() != null ? pt.getCustomerEmail() : "");
            item.put("sequenceNumber", pt.getSequenceNumber());
            item.put("priorityReason", pt.getPriorityReason() != null ? pt.getPriorityReason() : "");
            item.put("priorityRequestedAt", pt.getPriorityRequestedAt() != null ? pt.getPriorityRequestedAt().toString() : "");
            item.put("taskDescription", pt.getTaskDescription() != null ? pt.getTaskDescription() : "");
            if (pt.getProvider() != null) {
                item.put("providerId", pt.getProvider().getId());
                item.put("providerName", pt.getProvider().getName());
                item.put("providerDesignation", pt.getProvider().getDesignation());
            } else if (pt.getRequestedProvider() != null) {
                item.put("providerId", pt.getRequestedProvider().getId());
                item.put("providerName", pt.getRequestedProvider().getName());
                item.put("providerDesignation", pt.getRequestedProvider().getDesignation());
            } else {
                item.put("providerId", null);
                item.put("providerName", null);
                item.put("providerDesignation", null);
            }
            priorityRequestList.add(item);
        }

        int dailyMaxTokens = office.getDailyMaxTokens();
        long todayTokensCount = tokenRepository.countValidTokensTodayByOffice(officeId, startOfDay, endOfDay);
        long remainingCapacity = Math.max(0, dailyMaxTokens - todayTokensCount);
        boolean isOfficeFull = todayTokensCount >= dailyMaxTokens;

        // Available Providers in this office
        List<Provider> providers = providerRepository.findByOfficeIdAndActiveTrueOrderByIdAsc(officeId);
        List<Map<String, Object>> providerSummaries = new ArrayList<>();
        for (Provider p : providers) {
            Map<String, Object> pm = new HashMap<>();
            pm.put("id", p.getId());
            pm.put("name", p.getName());
            pm.put("designation", p.getDesignation());
            pm.put("onDuty", p.getOnDuty() != null ? p.getOnDuty() : true);
            pm.put("availableNow", providerService.isProviderAvailableNow(p));
            pm.put("dailyMaxTokens", p.getDailyMaxTokens());

            long pTodayTokens = tokenRepository.countValidTokensTodayByProvider(p.getId(), startOfDay, endOfDay);
            pm.put("todayTokensCount", pTodayTokens);
            if (p.getDailyMaxTokens() != null) {
                pm.put("remainingCapacity", Math.max(0, p.getDailyMaxTokens() - pTodayTokens));
                pm.put("isFull", pTodayTokens >= p.getDailyMaxTokens());
            } else {
                pm.put("remainingCapacity", remainingCapacity);
                pm.put("isFull", isOfficeFull);
            }
            providerSummaries.add(pm);
        }

        Map<String, Object> response = new HashMap<>();
        response.put("officeId", office.getId());
        response.put("officeName", office.getUser() != null ? office.getUser().getName() : "Office");
        response.put("category", office.getCategory() != null ? office.getCategory().name() : "OFFICE");
        response.put("isOpen", office.getIsOpen());
        response.put("activeToken", activeToken != null ? activeToken.getTokenNumber() : null);
        response.put("activeTokenDetails", activeToken != null ? Map.of(
                "id", activeToken.getId(),
                "tokenNumber", activeToken.getTokenNumber(),
                "customerName", activeToken.getCustomerName(),
                "customerPhone", activeToken.getCustomerPhone() != null ? activeToken.getCustomerPhone() : "",
                "status", activeToken.getStatus().name(),
                "sequenceNumber", activeToken.getSequenceNumber(),
                "calledAt", activeToken.getCalledAt() != null ? activeToken.getCalledAt().toString() : ""
        ) : null);
        response.put("waitingCount", waitingCount);
        response.put("completedCount", completedCount);
        response.put("avgWaitTimeMinutes", DEFAULT_SERVICE_TIME_MINUTES);
        response.put("nextTokens", nextTokens);
        response.put("unassignedTokens", unassignedList);
        response.put("unassignedCount", unassignedList.size());
        response.put("waitingTokens", allWaitingList);
        response.put("priorityRequests", priorityRequestList);
        response.put("priorityRequestsCount", priorityRequestList.size());
        response.put("availableProviders", providerSummaries);
        response.put("openingTime", office.getOpeningTime());
        response.put("closingTime", office.getClosingTime());
        response.put("dailyMaxTokens", dailyMaxTokens);
        response.put("todayTokensCount", todayTokensCount);
        response.put("remainingCapacity", remainingCapacity);
        response.put("isOfficeFull", isOfficeFull);

        return response;
    }

    /**
     * Operator Action: Call the next waiting customer.
     */
    public Map<String, Object> callNext(Long officeId) {
        // Complete current active token if one exists
        tokenRepository.findFirstByOfficeIdAndStatusInOrderBySequenceNumberAsc(
                officeId,
                List.of(TokenStatus.IN_SERVICE, TokenStatus.CALLED)
        ).ifPresent(this::completeToken);

        // Find first waiting token (priority tokens first)
        QueueToken nextToken = tokenRepository
                .findFirstByOfficeIdAndStatusOrderByIsPriorityDescSequenceNumberAsc(officeId, TokenStatus.WAITING)
                .orElse(null);

        if (nextToken != null) {
            nextToken.setStatus(TokenStatus.CALLED);
            nextToken.setCalledAt(LocalDateTime.now());
            tokenRepository.save(nextToken);
        }

        return getLiveQueue(officeId);
    }

    /**
     * Operator Action: Mark current active token as COMPLETED.
     */
    public Map<String, Object> completeCurrent(Long officeId) {
        tokenRepository.findFirstByOfficeIdAndStatusInOrderBySequenceNumberAsc(
                officeId,
                List.of(TokenStatus.IN_SERVICE, TokenStatus.CALLED)
        ).ifPresent(this::completeToken);

        return getLiveQueue(officeId);
    }

    /**
     * Operator Action: Skip/Hold current active token.
     */
    public Map<String, Object> skipCurrent(Long officeId) {
        tokenRepository.findFirstByOfficeIdAndStatusInOrderBySequenceNumberAsc(
                officeId,
                List.of(TokenStatus.IN_SERVICE, TokenStatus.CALLED)
        ).ifPresent(curr -> {
            curr.setStatus(TokenStatus.SKIPPED);
            tokenRepository.save(curr);
        });

        return getLiveQueue(officeId);
    }

    /**
     * Operator Action: Swap current active token with the next waiting customer.
     * The next waiting token is called to counter, and the current token becomes next in line.
     */
    public Map<String, Object> swapNext(Long officeId) {
        QueueToken currentToken = tokenRepository
                .findFirstByOfficeIdAndStatusInOrderBySequenceNumberAsc(
                        officeId,
                        List.of(TokenStatus.IN_SERVICE, TokenStatus.CALLED)
                ).orElseThrow(() -> new IllegalStateException("No customer currently called or being served to swap"));

        QueueToken nextToken = tokenRepository
                .findFirstByOfficeIdAndStatusOrderBySequenceNumberAsc(officeId, TokenStatus.WAITING)
                .orElseThrow(() -> new IllegalStateException("No waiting customer available to swap with"));

        int currentSeq = currentToken.getSequenceNumber();
        int nextSeq = nextToken.getSequenceNumber();

        if (currentSeq < nextSeq) {
            currentToken.setSequenceNumber(nextSeq);
            nextToken.setSequenceNumber(currentSeq);
        } else {
            currentToken.setSequenceNumber(nextSeq + 1);
            nextToken.setSequenceNumber(nextSeq);
        }

        currentToken.setStatus(TokenStatus.WAITING);
        currentToken.setCalledAt(null);

        nextToken.setStatus(TokenStatus.CALLED);
        nextToken.setCalledAt(LocalDateTime.now());

        tokenRepository.save(currentToken);
        tokenRepository.save(nextToken);

        return getLiveQueue(officeId);
    }

    /**
     * Operator Action: Forward an unassigned or waiting token to an available provider.
     */
    public Map<String, Object> forwardTokenToProvider(Long officeId, Long tokenId, Long providerId) {
        QueueToken token = tokenRepository.findById(tokenId)
                .orElseThrow(() -> new IllegalArgumentException("Token not found: " + tokenId));

        if (!token.getOffice().getId().equals(officeId)) {
            throw new IllegalArgumentException("Token does not belong to this office");
        }

        if (token.getStatus() != TokenStatus.WAITING && token.getStatus() != TokenStatus.CALLED) {
            throw new IllegalStateException("Only WAITING or CALLED tokens can be forwarded to a provider");
        }

        Provider provider = providerRepository.findByIdAndOfficeId(providerId, officeId)
                .orElseThrow(() -> new IllegalArgumentException("Provider not found or does not belong to this office"));

        // Validate provider daily limit if set
        if (provider.getDailyMaxTokens() != null) {
            LocalDateTime startOfDay = LocalDate.now().atStartOfDay();
            LocalDateTime endOfDay = LocalDate.now().atTime(LocalTime.MAX);
            long providerTokensToday = tokenRepository.countValidTokensTodayByProvider(providerId, startOfDay, endOfDay);
            if (providerTokensToday >= provider.getDailyMaxTokens()) {
                throw new IllegalStateException("Provider " + provider.getName() + " has reached their daily maximum limit of " + provider.getDailyMaxTokens() + " tokens.");
            }
        }

        token.setProvider(provider);
        token.setRequestedProvider(null);
        token.setRequestStatus(null);
        // If it was CALLED at the front desk, move it back to WAITING for the assigned provider
        if (token.getStatus() == TokenStatus.CALLED) {
            token.setStatus(TokenStatus.WAITING);
            token.setCalledAt(null);
        }
        tokenRepository.save(token);

        Map<String, Object> response = getLiveQueue(officeId);
        response.put("forwardedTokenNumber", token.getTokenNumber());
        response.put("assignedProviderName", provider.getName());
        return response;
    }

    /**
     * Operator Action: Request a provider whose limit is reached to take an extra token.
     */
    public Map<String, Object> requestTokenToProvider(Long officeId, Long tokenId, Long providerId) {
        QueueToken token = tokenRepository.findById(tokenId)
                .orElseThrow(() -> new IllegalArgumentException("Token not found: " + tokenId));

        if (!token.getOffice().getId().equals(officeId)) {
            throw new IllegalArgumentException("Token does not belong to this office");
        }

        if (token.getStatus() != TokenStatus.WAITING && token.getStatus() != TokenStatus.CALLED) {
            throw new IllegalStateException("Only WAITING or CALLED tokens can be requested for a provider");
        }

        Provider provider = providerRepository.findByIdAndOfficeId(providerId, officeId)
                .orElseThrow(() -> new IllegalArgumentException("Provider not found or does not belong to this office"));

        token.setRequestedProvider(provider);
        token.setRequestStatus("PENDING");
        tokenRepository.save(token);

        Map<String, Object> response = getLiveQueue(officeId);
        response.put("requestedTokenNumber", token.getTokenNumber());
        response.put("requestedProviderName", provider.getName());
        return response;
    }

    /**
     * Operator Action: Cancel a pending token forward request.
     */
    public Map<String, Object> cancelTokenRequest(Long officeId, Long tokenId) {
        QueueToken token = tokenRepository.findById(tokenId)
                .orElseThrow(() -> new IllegalArgumentException("Token not found: " + tokenId));

        if (!token.getOffice().getId().equals(officeId)) {
            throw new IllegalArgumentException("Token does not belong to this office");
        }

        token.setRequestedProvider(null);
        token.setRequestStatus(null);
        tokenRepository.save(token);

        return getLiveQueue(officeId);
    }

    /**
     * Operator Action: Office forwards customer's priority request to a provider.
     */
    public Map<String, Object> officeForwardPriority(Long officeId, Long tokenId, Long providerId) {
        QueueToken token = tokenRepository.findById(tokenId)
                .orElseThrow(() -> new IllegalArgumentException("Token not found: " + tokenId));

        if (!token.getOffice().getId().equals(officeId)) {
            throw new IllegalArgumentException("Token does not belong to this office");
        }

        if (token.getStatus() != TokenStatus.WAITING) {
            throw new IllegalStateException("Only WAITING tokens can have priority requests forwarded");
        }

        Provider provider = providerRepository.findByIdAndOfficeId(providerId, officeId)
                .orElseThrow(() -> new IllegalArgumentException("Provider not found or does not belong to this office"));

        token.setRequestedProvider(provider);
        token.setPriorityStatus("PENDING_PROVIDER");
        tokenRepository.save(token);

        return getLiveQueue(officeId);
    }

    /**
     * Operator Action: Office rejects customer's priority request.
     */
    public Map<String, Object> officeRejectPriority(Long officeId, Long tokenId) {
        QueueToken token = tokenRepository.findById(tokenId)
                .orElseThrow(() -> new IllegalArgumentException("Token not found: " + tokenId));

        if (!token.getOffice().getId().equals(officeId)) {
            throw new IllegalArgumentException("Token does not belong to this office");
        }

        token.setIsPriority(false);
        token.setPriorityStatus("REJECTED");
        tokenRepository.save(token);

        return getLiveQueue(officeId);
    }

    /**
     * Operator Action: Directly call / serve a specific unassigned token at the front desk.
     */
    public Map<String, Object> serveTokenAtDesk(Long officeId, Long tokenId) {
        // Complete current active token if one exists
        tokenRepository.findFirstByOfficeIdAndStatusInOrderBySequenceNumberAsc(
                officeId,
                List.of(TokenStatus.IN_SERVICE, TokenStatus.CALLED)
        ).ifPresent(this::completeToken);

        QueueToken token = tokenRepository.findById(tokenId)
                .orElseThrow(() -> new IllegalArgumentException("Token not found: " + tokenId));

        if (!token.getOffice().getId().equals(officeId)) {
            throw new IllegalArgumentException("Token does not belong to this office");
        }

        token.setStatus(TokenStatus.CALLED);
        token.setCalledAt(LocalDateTime.now());
        token.setServingStartedAt(LocalDateTime.now());
        tokenRepository.save(token);

        return getLiveQueue(officeId);
    }

    /**
     * Customer Action: Cancel token.
     */
    public Map<String, Object> cancelToken(Long tokenId) {
        QueueToken token = tokenRepository.findById(tokenId)
                .orElseThrow(() -> new RuntimeException("Token not found: " + tokenId));

        token.setStatus(TokenStatus.CANCELLED);
        tokenRepository.save(token);

        return Map.of("message", "Token cancelled successfully", "tokenId", tokenId);
    }

    /**
     * Get active token for a customer.
     */
    @Transactional(readOnly = true)
    public Map<String, Object> getMyActiveToken(Long customerId, String email) {
        List<QueueToken> activeList;

        if (customerId != null) {
            activeList = tokenRepository.findByCustomerIdAndStatusInOrderByBookedAtDesc(
                    customerId,
                    List.of(TokenStatus.WAITING, TokenStatus.CALLED, TokenStatus.IN_SERVICE)
            );
        } else if (email != null && !email.isBlank()) {
            activeList = tokenRepository.findByCustomerEmailAndStatusInOrderByBookedAtDesc(
                    email.trim(),
                    List.of(TokenStatus.WAITING, TokenStatus.CALLED, TokenStatus.IN_SERVICE)
            );
        } else {
            return Map.of("hasActiveToken", false);
        }

        if (activeList.isEmpty()) {
            return Map.of("hasActiveToken", false);
        }

        QueueToken token = activeList.get(0);
        Long officeId = token.getOffice().getId();

        Long peopleAhead;
        QueueToken serving;
        if (token.getProvider() != null) {
            peopleAhead = tokenRepository.countTokensAheadOfProvider(token.getProvider().getId(), token.getSequenceNumber());
            serving = tokenRepository.findFirstByProviderIdAndStatusInOrderBySequenceNumberAsc(
                    token.getProvider().getId(),
                    List.of(TokenStatus.IN_SERVICE, TokenStatus.CALLED)
            ).orElse(null);
        } else {
            peopleAhead = tokenRepository.countTokensAheadOf(officeId, token.getSequenceNumber());
            serving = tokenRepository.findFirstByOfficeIdAndStatusInOrderBySequenceNumberAsc(
                    officeId,
                    List.of(TokenStatus.IN_SERVICE, TokenStatus.CALLED)
            ).orElse(null);
        }

        Map<String, Object> result = new HashMap<>();
        result.put("hasActiveToken", true);
        result.put("token", token);
        result.put("tokenNumber", token.getTokenNumber());
        result.put("sequenceNumber", token.getSequenceNumber());
        result.put("status", token.getStatus().name());
        result.put("peopleAhead", peopleAhead != null ? peopleAhead : 0L);
        result.put("estimatedWaitMinutes", (peopleAhead != null ? peopleAhead : 0L) * DEFAULT_SERVICE_TIME_MINUTES);
        result.put("currentlyServing", serving != null ? serving.getTokenNumber() : "None");
        result.put("officeId", officeId);
        result.put("officeName", token.getOffice().getUser() != null ? token.getOffice().getUser().getName() : "Office");
        result.put("category", token.getOffice().getCategory() != null ? token.getOffice().getCategory().name() : "OFFICE");
        result.put("address", token.getOffice().getAddress());
        result.put("city", token.getOffice().getCity());
        if (token.getProvider() != null) {
            result.put("providerId", token.getProvider().getId());
            result.put("providerName", token.getProvider().getName());
            result.put("providerDesignation", token.getProvider().getDesignation());
        }

        return result;
    }

    /**
     * Get live queue metrics and token list for a specific provider.
     */
    @Transactional(readOnly = true)
    public Map<String, Object> getProviderLiveQueue(Long providerId) {
        Provider provider = providerRepository.findById(providerId)
                .orElseThrow(() -> new IllegalArgumentException("Provider not found: " + providerId));

        // Active serving/called token for this provider
        QueueToken activeToken = tokenRepository
                .findFirstByProviderIdAndStatusInOrderBySequenceNumberAsc(
                        providerId,
                        List.of(TokenStatus.IN_SERVICE, TokenStatus.CALLED)
                ).orElse(null);

        // Waiting tokens assigned to this provider (priority tokens first!)
        List<QueueToken> waitingTokens = tokenRepository
                .findByProviderIdAndStatusInOrderByIsPriorityDescSequenceNumberAsc(providerId, List.of(TokenStatus.WAITING));

        LocalDateTime startOfDay = LocalDateTime.of(LocalDate.now(), LocalTime.MIN);
        LocalDateTime endOfDay = LocalDateTime.of(LocalDate.now(), LocalTime.MAX);
        List<QueueToken> todayTokens = tokenRepository.findByProviderIdAndBookedAtBetweenOrderBySequenceNumberAsc(
                providerId, startOfDay, endOfDay
        );

        long completedCount = todayTokens.stream()
                .filter(t -> t.getStatus() == TokenStatus.COMPLETED)
                .count();

        long skippedCount = todayTokens.stream()
                .filter(t -> t.getStatus() == TokenStatus.SKIPPED)
                .count();

        List<Map<String, Object>> waitingTokenList = new ArrayList<>();
        for (int i = 0; i < waitingTokens.size(); i++) {
            QueueToken t = waitingTokens.get(i);
            Map<String, Object> item = new HashMap<>();
            item.put("id", t.getId());
            item.put("tokenNumber", t.getTokenNumber());
            item.put("customerName", t.getCustomerName());
            item.put("customerPhone", t.getCustomerPhone() != null ? t.getCustomerPhone() : "");
            item.put("sequenceNumber", t.getSequenceNumber());
            item.put("status", t.getStatus().name());
            item.put("estimatedWaitMinutes", t.getEstimatedWaitMinutes());
            item.put("position", i + 1);
            item.put("bookedAt", t.getBookedAt() != null ? t.getBookedAt().toString() : "");
            item.put("isPriority", Boolean.TRUE.equals(t.getIsPriority()));
            item.put("priorityStatus", t.getPriorityStatus() != null ? t.getPriorityStatus() : "NONE");
            item.put("priorityReason", t.getPriorityReason() != null ? t.getPriorityReason() : "");
            item.put("taskDescription", t.getTaskDescription() != null ? t.getTaskDescription() : "");
            waitingTokenList.add(item);
        }

        Map<String, Object> response = new HashMap<>();
        response.put("providerId", provider.getId());
        response.put("providerName", provider.getName());
        response.put("activeToken", activeToken != null ? activeToken.getTokenNumber() : null);
        response.put("activeTokenDetails", activeToken != null ? Map.of(
                "id", activeToken.getId(),
                "tokenNumber", activeToken.getTokenNumber(),
                "customerName", activeToken.getCustomerName(),
                "customerPhone", activeToken.getCustomerPhone() != null ? activeToken.getCustomerPhone() : "",
                "status", activeToken.getStatus().name(),
                "sequenceNumber", activeToken.getSequenceNumber(),
                "calledAt", activeToken.getCalledAt() != null ? activeToken.getCalledAt().toString() : ""
        ) : null);
        List<QueueToken> incomingRequests = tokenRepository
                .findByRequestedProviderIdAndRequestStatusAndStatusInOrderBySequenceNumberAsc(
                        providerId, "PENDING", List.of(TokenStatus.WAITING, TokenStatus.CALLED)
                );

        List<Map<String, Object>> incomingRequestList = new ArrayList<>();
        for (QueueToken req : incomingRequests) {
            Map<String, Object> reqMap = new HashMap<>();
            reqMap.put("id", req.getId());
            reqMap.put("tokenNumber", req.getTokenNumber());
            reqMap.put("customerName", req.getCustomerName());
            reqMap.put("customerPhone", req.getCustomerPhone() != null ? req.getCustomerPhone() : "");
            reqMap.put("sequenceNumber", req.getSequenceNumber());
            reqMap.put("bookedAt", req.getBookedAt() != null ? req.getBookedAt().toString() : "");
            reqMap.put("officeName", req.getOffice().getUser() != null ? req.getOffice().getUser().getName() : "Office Desk");
            incomingRequestList.add(reqMap);
        }

        // Incoming Priority Requests forwarded by office
        List<QueueToken> incomingPriorityRequests = tokenRepository
                .findByRequestedProviderIdAndPriorityStatusAndStatusInOrderByPriorityRequestedAtAsc(
                        providerId, "PENDING_PROVIDER", List.of(TokenStatus.WAITING)
                );

        List<Map<String, Object>> priorityRequestList = new ArrayList<>();
        for (QueueToken req : incomingPriorityRequests) {
            Map<String, Object> reqMap = new HashMap<>();
            reqMap.put("id", req.getId());
            reqMap.put("tokenNumber", req.getTokenNumber());
            reqMap.put("customerName", req.getCustomerName());
            reqMap.put("customerPhone", req.getCustomerPhone() != null ? req.getCustomerPhone() : "");
            reqMap.put("customerEmail", req.getCustomerEmail() != null ? req.getCustomerEmail() : "");
            reqMap.put("sequenceNumber", req.getSequenceNumber());
            reqMap.put("priorityReason", req.getPriorityReason() != null ? req.getPriorityReason() : "");
            reqMap.put("priorityRequestedAt", req.getPriorityRequestedAt() != null ? req.getPriorityRequestedAt().toString() : "");
            reqMap.put("taskDescription", req.getTaskDescription() != null ? req.getTaskDescription() : "");
            reqMap.put("officeName", req.getOffice().getUser() != null ? req.getOffice().getUser().getName() : "Office");
            priorityRequestList.add(reqMap);
        }

        response.put("waitingCount", waitingTokens.size());
        response.put("completedCount", completedCount);
        response.put("skippedCount", skippedCount);
        response.put("waitingTokens", waitingTokenList);
        response.put("todayTotalTokens", todayTokens.size());
        response.put("incomingRequests", incomingRequestList);
        response.put("incomingRequestsCount", incomingRequestList.size());
        response.put("priorityRequests", priorityRequestList);
        response.put("priorityRequestsCount", priorityRequestList.size());

        return response;
    }

    /**
     * Provider calls the next waiting customer assigned to them.
     */
    public Map<String, Object> providerCallNext(Long providerId) {
        // Complete current active token if one exists
        tokenRepository.findFirstByProviderIdAndStatusInOrderBySequenceNumberAsc(
                providerId,
                List.of(TokenStatus.IN_SERVICE, TokenStatus.CALLED)
        ).ifPresent(this::completeToken);

        // Find first waiting token assigned to this provider (priority tokens first!)
        QueueToken nextToken = tokenRepository
                .findFirstByProviderIdAndStatusOrderByIsPriorityDescSequenceNumberAsc(providerId, TokenStatus.WAITING)
                .orElse(null);

        if (nextToken != null) {
            nextToken.setStatus(TokenStatus.CALLED);
            nextToken.setCalledAt(LocalDateTime.now());
            tokenRepository.save(nextToken);
        }

        return getProviderLiveQueue(providerId);
    }

    /**
     * Provider marks a called token as IN_SERVICE.
     */
    public Map<String, Object> providerServeToken(Long providerId, Long tokenId) {
        QueueToken token = tokenRepository.findById(tokenId)
                .orElseThrow(() -> new IllegalArgumentException("Token not found: " + tokenId));

        if (token.getProvider() == null || !token.getProvider().getId().equals(providerId)) {
            throw new IllegalArgumentException("Token is not assigned to this provider");
        }

        token.setStatus(TokenStatus.IN_SERVICE);
        if (token.getServingStartedAt() == null) {
            token.setServingStartedAt(LocalDateTime.now());
        }
        tokenRepository.save(token);

        return getProviderLiveQueue(providerId);
    }

    /**
     * Provider marks their current active token as COMPLETED.
     */
    public Map<String, Object> providerCompleteCurrent(Long providerId) {
        tokenRepository.findFirstByProviderIdAndStatusInOrderBySequenceNumberAsc(
                providerId,
                List.of(TokenStatus.IN_SERVICE, TokenStatus.CALLED)
        ).ifPresent(this::completeToken);

        return getProviderLiveQueue(providerId);
    }

    /**
     * Provider skips/holds their current active token.
     */
    public Map<String, Object> providerSkipCurrent(Long providerId) {
        tokenRepository.findFirstByProviderIdAndStatusInOrderBySequenceNumberAsc(
                providerId,
                List.of(TokenStatus.IN_SERVICE, TokenStatus.CALLED)
        ).ifPresent(curr -> {
            curr.setStatus(TokenStatus.SKIPPED);
            tokenRepository.save(curr);
        });

        return getProviderLiveQueue(providerId);
    }

    /**
     * Provider Action: Swap current active token with the next waiting customer assigned to this provider.
     * The next waiting token is called to counter, and the current token becomes next in line.
     */
    public Map<String, Object> providerSwapNext(Long providerId) {
        QueueToken currentToken = tokenRepository
                .findFirstByProviderIdAndStatusInOrderBySequenceNumberAsc(
                        providerId,
                        List.of(TokenStatus.IN_SERVICE, TokenStatus.CALLED)
                ).orElseThrow(() -> new IllegalStateException("No customer currently called or being served to swap"));

        QueueToken nextToken = tokenRepository
                .findFirstByProviderIdAndStatusOrderBySequenceNumberAsc(providerId, TokenStatus.WAITING)
                .orElseThrow(() -> new IllegalStateException("No waiting customer assigned to you to swap with"));

        int currentSeq = currentToken.getSequenceNumber();
        int nextSeq = nextToken.getSequenceNumber();

        if (currentSeq < nextSeq) {
            currentToken.setSequenceNumber(nextSeq);
            nextToken.setSequenceNumber(currentSeq);
        } else {
            currentToken.setSequenceNumber(nextSeq + 1);
            nextToken.setSequenceNumber(nextSeq);
        }

        currentToken.setStatus(TokenStatus.WAITING);
        currentToken.setCalledAt(null);

        nextToken.setStatus(TokenStatus.CALLED);
        nextToken.setCalledAt(LocalDateTime.now());

        tokenRepository.save(currentToken);
        tokenRepository.save(nextToken);

        return getProviderLiveQueue(providerId);
    }

    /**
     * Provider Action: Accept an extra token requested by the office.
     */
    public Map<String, Object> providerAcceptTokenRequest(Long providerId, Long tokenId) {
        QueueToken token = tokenRepository.findById(tokenId)
                .orElseThrow(() -> new IllegalArgumentException("Token not found: " + tokenId));

        if (token.getRequestedProvider() == null || !token.getRequestedProvider().getId().equals(providerId)) {
            throw new IllegalArgumentException("This token was not requested to you");
        }

        if (!"PENDING".equalsIgnoreCase(token.getRequestStatus())) {
            throw new IllegalStateException("Token request is not in PENDING state");
        }

        Provider provider = token.getRequestedProvider();
        token.setProvider(provider);
        token.setRequestedProvider(null);
        token.setRequestStatus(null);

        // If it was CALLED at the front desk, move it back to WAITING for the assigned provider
        if (token.getStatus() == TokenStatus.CALLED) {
            token.setStatus(TokenStatus.WAITING);
            token.setCalledAt(null);
        }
        tokenRepository.save(token);

        return getProviderLiveQueue(providerId);
    }

    /**
     * Provider Action: Decline an extra token requested by the office.
     */
    public Map<String, Object> providerDeclineTokenRequest(Long providerId, Long tokenId) {
        QueueToken token = tokenRepository.findById(tokenId)
                .orElseThrow(() -> new IllegalArgumentException("Token not found: " + tokenId));

        if (token.getRequestedProvider() == null || !token.getRequestedProvider().getId().equals(providerId)) {
            throw new IllegalArgumentException("This token was not requested to you");
        }

        token.setRequestedProvider(null);
        token.setRequestStatus("REJECTED");
        tokenRepository.save(token);

        return getProviderLiveQueue(providerId);
    }

    /**
     * Provider Action: Accept a priority request.
     */
    public Map<String, Object> providerAcceptPriority(Long providerId, Long tokenId) {
        QueueToken token = tokenRepository.findById(tokenId)
                .orElseThrow(() -> new IllegalArgumentException("Token not found: " + tokenId));

        if ((token.getRequestedProvider() == null || !token.getRequestedProvider().getId().equals(providerId))
                && (token.getProvider() == null || !token.getProvider().getId().equals(providerId))) {
            throw new IllegalArgumentException("This priority request is not assigned to you");
        }

        Provider provider = providerRepository.findById(providerId)
                .orElseThrow(() -> new IllegalArgumentException("Provider not found: " + providerId));

        token.setIsPriority(true);
        token.setPriorityStatus("ACCEPTED");
        token.setProvider(provider);
        token.setRequestedProvider(null);
        tokenRepository.save(token);

        return getProviderLiveQueue(providerId);
    }

    /**
     * Provider Action: Reject a priority request.
     * Token remains in normal queue preserving existing order.
     */
    public Map<String, Object> providerRejectPriority(Long providerId, Long tokenId) {
        QueueToken token = tokenRepository.findById(tokenId)
                .orElseThrow(() -> new IllegalArgumentException("Token not found: " + tokenId));

        if ((token.getRequestedProvider() == null || !token.getRequestedProvider().getId().equals(providerId))
                && (token.getProvider() == null || !token.getProvider().getId().equals(providerId))) {
            throw new IllegalArgumentException("This priority request is not assigned to you");
        }

        token.setIsPriority(false);
        token.setPriorityStatus("REJECTED");
        token.setRequestedProvider(null);
        tokenRepository.save(token);

        return getProviderLiveQueue(providerId);
    }

    /**
     * Get token history for a customer.
     */
    @Transactional(readOnly = true)
    public List<QueueToken> getMyTokenHistory(Long customerId, String email) {
        if (customerId != null) {
            return tokenRepository.findByCustomerIdOrderByBookedAtDesc(customerId);
        } else if (email != null && !email.isBlank()) {
            return tokenRepository.findByCustomerEmailOrderByBookedAtDesc(email.trim());
        }
        return List.of();
    }

    private void completeToken(QueueToken token) {
        LocalDateTime now = LocalDateTime.now();
        token.setStatus(TokenStatus.COMPLETED);
        token.setCompletedAt(now);

        LocalDateTime servingStart = token.getServingStartedAt();
        if (servingStart == null) {
            servingStart = token.getCalledAt() != null ? token.getCalledAt() : token.getBookedAt();
            token.setServingStartedAt(servingStart);
        }

        if (servingStart != null) {
            long seconds = Duration.between(servingStart, now).getSeconds();
            if (seconds < 0) seconds = 0;
            token.setServiceDurationSeconds(seconds);
            token.setServiceDurationMinutes((int) Math.round(seconds / 60.0));
        } else {
            token.setServiceDurationSeconds(0L);
            token.setServiceDurationMinutes(0);
        }
        tokenRepository.save(token);
    }

    private String maskName(String name) {
        if (name == null || name.isBlank()) return "Customer";
        String[] parts = name.trim().split("\\s+");
        if (parts.length > 1) {
            return parts[0] + " " + parts[1].charAt(0) + ".";
        }
        return parts[0];
    }
}
