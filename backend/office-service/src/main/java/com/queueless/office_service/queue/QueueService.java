package com.queueless.office_service.queue;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.queueless.office_service.user.OfficeProfile;
import com.queueless.office_service.user.OfficeProfileRepository;

@Service
@Transactional
public class QueueService {

    private final QueueTokenRepository tokenRepository;
    private final OfficeProfileRepository officeProfileRepository;

    private static final int DEFAULT_SERVICE_TIME_MINUTES = 12;

    public QueueService(
            QueueTokenRepository tokenRepository,
            OfficeProfileRepository officeProfileRepository) {
        this.tokenRepository = tokenRepository;
        this.officeProfileRepository = officeProfileRepository;
    }

    /**
     * Book a new token for an office.
     */
    public Map<String, Object> bookToken(
            Long officeId,
            Long customerId,
            String customerName,
            String customerPhone,
            String customerEmail) {

        OfficeProfile office = officeProfileRepository.findById(officeId)
                .orElseThrow(() -> new RuntimeException("Office not found with id: " + officeId));

        LocalDateTime startOfDay = LocalDateTime.of(LocalDate.now(), LocalTime.MIN);
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
        token.setSequenceNumber(nextSeq);
        token.setTokenNumber(tokenNumber);
        token.setCustomerId(customerId);
        token.setCustomerName(customerName != null && !customerName.isBlank() ? customerName.trim() : "Customer");
        token.setCustomerPhone(customerPhone);
        token.setCustomerEmail(customerEmail);
        token.setStatus(TokenStatus.WAITING);
        token.setEstimatedWaitMinutes(waitTime);
        token.setBookedAt(LocalDateTime.now());

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

        Map<String, Object> response = new HashMap<>();
        response.put("officeId", office.getId());
        response.put("officeName", office.getUser() != null ? office.getUser().getName() : "Office");
        response.put("category", office.getCategory() != null ? office.getCategory().name() : "OFFICE");
        response.put("activeToken", activeToken != null ? activeToken.getTokenNumber() : null);
        response.put("activeTokenDetails", activeToken);
        response.put("waitingCount", waitingCount);
        response.put("completedCount", completedCount);
        response.put("avgWaitTimeMinutes", DEFAULT_SERVICE_TIME_MINUTES);
        response.put("nextTokens", nextTokens);
        response.put("openingTime", office.getOpeningTime());
        response.put("closingTime", office.getClosingTime());

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
        ).ifPresent(curr -> {
            curr.setStatus(TokenStatus.COMPLETED);
            curr.setCompletedAt(LocalDateTime.now());
            tokenRepository.save(curr);
        });

        // Find first waiting token
        QueueToken nextToken = tokenRepository
                .findFirstByOfficeIdAndStatusOrderBySequenceNumberAsc(officeId, TokenStatus.WAITING)
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
        ).ifPresent(curr -> {
            curr.setStatus(TokenStatus.COMPLETED);
            curr.setCompletedAt(LocalDateTime.now());
            tokenRepository.save(curr);
        });

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

        Long peopleAhead = tokenRepository.countTokensAheadOf(officeId, token.getSequenceNumber());
        QueueToken serving = tokenRepository.findFirstByOfficeIdAndStatusInOrderBySequenceNumberAsc(
                officeId,
                List.of(TokenStatus.IN_SERVICE, TokenStatus.CALLED)
        ).orElse(null);

        Map<String, Object> result = new HashMap<>();
        result.put("hasActiveToken", true);
        result.put("token", token);
        result.put("tokenNumber", token.getTokenNumber());
        result.put("sequenceNumber", token.getSequenceNumber());
        result.put("status", token.getStatus().name());
        result.put("peopleAhead", peopleAhead);
        result.put("estimatedWaitMinutes", peopleAhead * DEFAULT_SERVICE_TIME_MINUTES);
        result.put("currentlyServing", serving != null ? serving.getTokenNumber() : "None");
        result.put("officeId", officeId);
        result.put("officeName", token.getOffice().getUser() != null ? token.getOffice().getUser().getName() : "Office");
        result.put("category", token.getOffice().getCategory() != null ? token.getOffice().getCategory().name() : "OFFICE");
        result.put("address", token.getOffice().getAddress());
        result.put("city", token.getOffice().getCity());

        return result;
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

    private String maskName(String name) {
        if (name == null || name.isBlank()) return "Customer";
        String[] parts = name.trim().split("\\s+");
        if (parts.length > 1) {
            return parts[0] + " " + parts[1].charAt(0) + ".";
        }
        return parts[0];
    }
}
