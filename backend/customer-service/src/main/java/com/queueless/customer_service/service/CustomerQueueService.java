package com.queueless.customer_service.service;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.queueless.customer_service.model.OfficeProfile;
import com.queueless.customer_service.model.Provider;
import com.queueless.customer_service.model.QueueToken;
import com.queueless.customer_service.model.TokenStatus;
import com.queueless.customer_service.repository.OfficeProfileRepository;
import com.queueless.customer_service.repository.ProviderRepository;
import com.queueless.customer_service.repository.QueueTokenRepository;

@Service
@Transactional
public class CustomerQueueService {

    private final QueueTokenRepository tokenRepository;
    private final OfficeProfileRepository officeProfileRepository;
    private final ProviderRepository providerRepository;
    private final ProviderAvailabilityService providerAvailabilityService;

    private static final int DEFAULT_SERVICE_TIME_MINUTES = 12;

    public CustomerQueueService(
            QueueTokenRepository tokenRepository,
            OfficeProfileRepository officeProfileRepository,
            ProviderRepository providerRepository,
            ProviderAvailabilityService providerAvailabilityService) {
        this.tokenRepository = tokenRepository;
        this.officeProfileRepository = officeProfileRepository;
        this.providerRepository = providerRepository;
        this.providerAvailabilityService = providerAvailabilityService;
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

    public Map<String, Object> bookToken(
            Long officeId,
            Long providerId,
            Long customerId,
            String customerName,
            String customerPhone,
            String customerEmail,
            String taskDescription) {

        OfficeProfile office = officeProfileRepository.findByIdForUpdate(officeId)
                .orElseThrow(() -> new IllegalArgumentException("Office not found with id: " + officeId));

        if (Boolean.FALSE.equals(office.getIsOpen())) {
            throw new IllegalStateException("Office is currently closed. Cannot book token at this time.");
        }

        LocalDate today = LocalDate.now();
        LocalDateTime startOfDay = today.atStartOfDay();
        LocalDateTime endOfDay = today.atTime(LocalTime.MAX);

        // Enforce One Active Token Per Office Limit
        List<TokenStatus> activeStatuses = List.of(TokenStatus.WAITING, TokenStatus.CALLED, TokenStatus.IN_SERVICE);
        QueueToken existingActiveToken = null;
        if (customerId != null) {
            existingActiveToken = tokenRepository
                    .findFirstByOfficeIdAndCustomerIdAndStatusInOrderByBookedAtDesc(officeId, customerId, activeStatuses)
                    .orElse(null);
        }
        if (existingActiveToken == null && customerEmail != null && !customerEmail.isBlank()) {
            existingActiveToken = tokenRepository
                    .findFirstByOfficeIdAndCustomerEmailAndStatusInOrderByBookedAtDesc(officeId, customerEmail.trim(), activeStatuses)
                    .orElse(null);
        }

        if (existingActiveToken != null) {
            throw new IllegalStateException("You already have an active token (" + existingActiveToken.getTokenNumber() + ") for this office. Please complete or cancel your current token before booking a new one.");
        }

        // Daily limit check
        long officeTokensToday = tokenRepository.countValidTokensTodayByOffice(officeId, startOfDay, endOfDay);
        int officeDailyMax = office.getDailyMaxTokens() != null ? office.getDailyMaxTokens() : 60;
        if (officeTokensToday >= officeDailyMax) {
            throw new IllegalStateException("Office has reached its daily maximum limit of " + officeDailyMax + " tokens for today.");
        }

        // Provider check if selected
        Provider provider = null;
        if (providerId != null) {
            provider = providerRepository.findByIdAndOfficeId(providerId, officeId)
                    .orElseThrow(() -> new IllegalArgumentException("Provider not found or does not belong to this office"));

            if (!providerAvailabilityService.isProviderAvailableNow(provider)) {
                throw new IllegalStateException("Provider is currently unavailable or off duty");
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

        int avgServiceTime = getEffectiveAverageServiceMinutes(officeId, provider != null ? provider.getId() : null);
        Long currentWaiting = tokenRepository.countByOfficeIdAndStatus(officeId, TokenStatus.WAITING);
        int waitTime = (int) (currentWaiting * avgServiceTime);

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
        response.put("avgServiceTimeMinutes", avgServiceTime);
        response.put("isNewOffice", isOfficeNew(officeId));
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

    @Transactional(readOnly = true)
    public Map<String, Object> getMyActiveToken(Long customerId, String email) {
        return getMyActiveToken(null, customerId, email);
    }

    @Transactional(readOnly = true)
    public Map<String, Object> getMyActiveToken(Long targetOfficeId, Long customerId, String email) {
        List<QueueToken> tokens = new ArrayList<>();
        List<TokenStatus> activeStatuses = List.of(TokenStatus.WAITING, TokenStatus.CALLED, TokenStatus.IN_SERVICE);

        if (targetOfficeId != null) {
            if (customerId != null) {
                tokens = tokenRepository.findByOfficeIdAndCustomerIdAndStatusInOrderByBookedAtDesc(targetOfficeId, customerId, activeStatuses);
            }
            if (tokens.isEmpty() && email != null && !email.isBlank()) {
                tokens = tokenRepository.findByOfficeIdAndCustomerEmailAndStatusInOrderByBookedAtDesc(targetOfficeId, email.trim(), activeStatuses);
            }
        } else {
            if (customerId != null) {
                tokens = tokenRepository.findByCustomerIdAndStatusInOrderByBookedAtDesc(customerId, activeStatuses);
            }
            if (tokens.isEmpty() && email != null && !email.isBlank()) {
                tokens = tokenRepository.findByCustomerEmailAndStatusInOrderByBookedAtDesc(email.trim(), activeStatuses);
            }
        }

        if (tokens.isEmpty()) {
            return Map.of("hasActiveToken", false);
        }

        QueueToken activeToken = tokens.get(0);
        Long officeId = activeToken.getOffice().getId();
        Long providerId = activeToken.getProvider() != null ? activeToken.getProvider().getId() : null;
        int avgServiceTime = getEffectiveAverageServiceMinutes(officeId, providerId);
        boolean isNew = isOfficeNew(officeId);

        boolean isTokenPriority = Boolean.TRUE.equals(activeToken.getIsPriority());
        Long waitingAhead;
        Long deskOccupied;
        Long priorityTokensAhead = 0L;

        if (providerId != null) {
            deskOccupied = tokenRepository.countByProviderIdAndStatusIn(providerId, List.of(TokenStatus.IN_SERVICE, TokenStatus.CALLED));
            if (isTokenPriority) {
                waitingAhead = tokenRepository.countPriorityTokensAheadOfProvider(providerId, activeToken.getSequenceNumber());
                priorityTokensAhead = waitingAhead;
            } else {
                waitingAhead = tokenRepository.countStandardTokensAheadOfProvider(providerId, activeToken.getSequenceNumber());
                priorityTokensAhead = tokenRepository.countWaitingPriorityTokensInProvider(providerId);
            }
        } else {
            deskOccupied = tokenRepository.countByOfficeIdAndStatusIn(officeId, List.of(TokenStatus.IN_SERVICE, TokenStatus.CALLED));
            if (isTokenPriority) {
                waitingAhead = tokenRepository.countPriorityTokensAheadOfOffice(officeId, activeToken.getSequenceNumber());
                priorityTokensAhead = waitingAhead;
            } else {
                waitingAhead = tokenRepository.countStandardTokensAheadOfOffice(officeId, activeToken.getSequenceNumber());
                priorityTokensAhead = tokenRepository.countWaitingPriorityTokensInOffice(officeId);
            }
        }

        long totalPeopleAhead = (waitingAhead != null ? waitingAhead : 0L) + (deskOccupied != null ? deskOccupied : 0L);

        int estimatedWait;
        if (activeToken.getStatus() == TokenStatus.CALLED || activeToken.getStatus() == TokenStatus.IN_SERVICE) {
            estimatedWait = 0;
            totalPeopleAhead = 0;
        } else {
            estimatedWait = (int) (totalPeopleAhead * avgServiceTime);
        }

        Map<String, Object> response = new HashMap<>();
        response.put("hasActiveToken", true);
        response.put("token", activeToken);
        response.put("id", activeToken.getId());
        response.put("tokenId", activeToken.getId());
        response.put("tokenNumber", activeToken.getTokenNumber());
        response.put("sequenceNumber", activeToken.getSequenceNumber());
        response.put("status", activeToken.getStatus().name());
        response.put("isPriority", Boolean.TRUE.equals(activeToken.getIsPriority()));
        response.put("priorityStatus", activeToken.getPriorityStatus() != null ? activeToken.getPriorityStatus() : "NONE");
        response.put("priorityReason", activeToken.getPriorityReason());
        response.put("priorityRequestedAt", activeToken.getPriorityRequestedAt());
        response.put("taskDescription", activeToken.getTaskDescription());
        response.put("peopleAhead", totalPeopleAhead);
        response.put("estimatedWaitMinutes", estimatedWait);
        response.put("avgServiceTimeMinutes", avgServiceTime);
        response.put("isNewOffice", isNew);
        response.put("priorityTokensAhead", priorityTokensAhead != null ? priorityTokensAhead : 0L);
        response.put("isDeskOccupied", deskOccupied != null && deskOccupied > 0);
        response.put("officeId", activeToken.getOffice().getId());
        response.put("officeName", activeToken.getOffice().getUser() != null ? activeToken.getOffice().getUser().getName() : "Office");
        response.put("officeAddress", activeToken.getOffice().getAddress());
        response.put("category", activeToken.getOffice().getCategory() != null ? activeToken.getOffice().getCategory().name() : "OFFICE");
        if (activeToken.getProvider() != null) {
            response.put("providerId", activeToken.getProvider().getId());
            response.put("providerName", activeToken.getProvider().getName());
            response.put("providerDesignation", activeToken.getProvider().getDesignation());
        }
        return response;
    }

    private int getEffectiveAverageServiceMinutes(Long officeId, Long providerId) {
        Double avg = null;
        if (providerId != null) {
            avg = tokenRepository.findAvgServiceDurationMinutesByProvider(providerId);
        }
        if (avg == null || avg <= 0) {
            avg = tokenRepository.findAvgServiceDurationMinutesByOffice(officeId);
        }
        if (avg != null && avg > 0) {
            return Math.max(1, (int) Math.round(avg));
        }
        return DEFAULT_SERVICE_TIME_MINUTES; // 12 default if office is new / no completion history
    }

    private boolean isOfficeNew(Long officeId) {
        Long completedCount = tokenRepository.countCompletedTokensByOffice(officeId);
        return completedCount == null || completedCount == 0;
    }

    @Transactional(readOnly = true)
    public List<Map<String, Object>> getMyTokenHistory(Long customerId, String email) {
        List<QueueToken> tokens = new ArrayList<>();
        if (customerId != null) {
            tokens = tokenRepository.findByCustomerIdOrderByBookedAtDesc(customerId);
        }
        if (tokens.isEmpty() && email != null && !email.isBlank()) {
            tokens = tokenRepository.findByCustomerEmailOrderByBookedAtDesc(email.trim());
        }

        List<Map<String, Object>> history = new ArrayList<>();
        for (QueueToken t : tokens) {
            Map<String, Object> m = new HashMap<>();
            m.put("id", t.getId());
            m.put("tokenNumber", t.getTokenNumber());
            m.put("sequenceNumber", t.getSequenceNumber());
            m.put("status", t.getStatus().name());
            m.put("bookedAt", t.getBookedAt());
            m.put("calledAt", t.getCalledAt());
            m.put("completedAt", t.getCompletedAt());
            LocalDateTime servingStartedAt = t.getServingStartedAt();
            Long durationSeconds = t.getServiceDurationSeconds();
            Integer durationMinutes = t.getServiceDurationMinutes();

            if (t.getStatus() == TokenStatus.COMPLETED) {
                if (servingStartedAt == null) {
                    servingStartedAt = t.getCalledAt() != null ? t.getCalledAt() : t.getBookedAt();
                }
                if (durationSeconds == null && t.getCompletedAt() != null && servingStartedAt != null) {
                    durationSeconds = Math.max(0, java.time.Duration.between(servingStartedAt, t.getCompletedAt()).getSeconds());
                    durationMinutes = (int) Math.round(durationSeconds / 60.0);
                }
            }

            m.put("servingStartedAt", servingStartedAt);
            m.put("serviceDurationSeconds", durationSeconds);
            m.put("serviceDurationMinutes", durationMinutes);
            m.put("officeId", t.getOffice().getId());
            m.put("officeName", t.getOffice().getUser() != null ? t.getOffice().getUser().getName() : "Office");
            m.put("category", t.getOffice().getCategory() != null ? t.getOffice().getCategory().name() : "OFFICE");
            if (t.getProvider() != null) {
                m.put("providerId", t.getProvider().getId());
                m.put("providerName", t.getProvider().getName());
            }
            history.add(m);
        }
        return history;
    }

    public boolean cancelToken(Long tokenId, Long customerId, String email) {
        QueueToken token = tokenRepository.findById(tokenId)
                .orElseThrow(() -> new IllegalArgumentException("Token not found: " + tokenId));

        if (token.getStatus() != TokenStatus.WAITING) {
            throw new IllegalStateException("Only waiting tokens can be cancelled");
        }

        if (customerId != null && !customerId.equals(token.getCustomerId())) {
            if (email == null || !email.equalsIgnoreCase(token.getCustomerEmail())) {
                throw new IllegalStateException("You are not authorized to cancel this token");
            }
        }

        token.setStatus(TokenStatus.CANCELLED);
        tokenRepository.save(token);
        return true;
    }

    @Transactional
    public Map<String, Object> requestPriority(Long tokenId, String reason, Long customerId, String email) {
        QueueToken token = tokenRepository.findById(tokenId)
                .orElseThrow(() -> new IllegalArgumentException("Token not found: " + tokenId));

        if (token.getStatus() != TokenStatus.WAITING) {
            throw new IllegalStateException("Priority can only be requested for waiting tokens");
        }

        if (customerId != null && !customerId.equals(token.getCustomerId())) {
            if (email == null || !email.equalsIgnoreCase(token.getCustomerEmail())) {
                throw new IllegalStateException("You are not authorized to request priority for this token");
            }
        }

        if ("PENDING_OFFICE".equalsIgnoreCase(token.getPriorityStatus()) || "PENDING_PROVIDER".equalsIgnoreCase(token.getPriorityStatus())) {
            throw new IllegalStateException("A priority request is already pending review");
        }

        if (Boolean.TRUE.equals(token.getIsPriority()) || "ACCEPTED".equalsIgnoreCase(token.getPriorityStatus())) {
            throw new IllegalStateException("This token has already been granted priority");
        }

        token.setPriorityReason(reason != null ? reason.trim() : "");
        token.setPriorityStatus("PENDING_OFFICE");
        token.setPriorityRequestedAt(LocalDateTime.now());
        QueueToken saved = tokenRepository.save(token);

        Map<String, Object> response = new HashMap<>();
        response.put("success", true);
        response.put("message", "Priority request submitted successfully");
        response.put("id", saved.getId());
        response.put("tokenId", saved.getId());
        response.put("tokenNumber", saved.getTokenNumber());
        response.put("isPriority", Boolean.TRUE.equals(saved.getIsPriority()));
        response.put("priorityStatus", saved.getPriorityStatus());
        response.put("priorityReason", saved.getPriorityReason());
        response.put("priorityRequestedAt", saved.getPriorityRequestedAt());
        return response;
    }

    @Transactional(readOnly = true)
    public Map<String, Object> getLiveQueue(Long officeId) {
        OfficeProfile office = officeProfileRepository.findById(officeId)
                .orElseThrow(() -> new IllegalArgumentException("Office not found: " + officeId));

        LocalDate today = LocalDate.now();
        LocalDateTime startOfDay = today.atStartOfDay();
        LocalDateTime endOfDay = today.atTime(LocalTime.MAX);

        Long waitingCount = tokenRepository.countByOfficeIdAndStatus(officeId, TokenStatus.WAITING);
        QueueToken activeToken = tokenRepository.findFirstByOfficeIdAndStatusInOrderBySequenceNumberAsc(
                officeId,
                List.of(TokenStatus.IN_SERVICE, TokenStatus.CALLED)
        ).orElse(null);

        long tokensBookedToday = tokenRepository.countValidTokensTodayByOffice(officeId, startOfDay, endOfDay);
        int dailyMax = office.getDailyMaxTokens() != null ? office.getDailyMaxTokens() : 60;
        boolean isFull = tokensBookedToday >= dailyMax;

        int avgServiceTime = getEffectiveAverageServiceMinutes(officeId, null);
        boolean isNew = isOfficeNew(officeId);

        Map<String, Object> live = new HashMap<>();
        live.put("officeId", officeId);
        live.put("officeName", office.getUser() != null ? office.getUser().getName() : "Office");
        live.put("isOpen", office.getIsOpen());
        live.put("waitingCount", waitingCount != null ? waitingCount : 0);
        live.put("activeToken", activeToken != null ? activeToken.getTokenNumber() : null);
        live.put("avgServiceTimeMinutes", avgServiceTime);
        live.put("isNewOffice", isNew);
        live.put("estimatedWaitMinutes", (waitingCount != null ? waitingCount : 0) * avgServiceTime);
        live.put("dailyMaxTokens", dailyMax);
        live.put("tokensBookedToday", tokensBookedToday);
        live.put("isOfficeFull", isFull);
        live.put("remainingCapacity", Math.max(0, dailyMax - tokensBookedToday));
        return live;
    }
}
