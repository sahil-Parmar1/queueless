package com.queueless.customer_service.service;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.queueless.customer_service.dto.ProviderResponse;
import com.queueless.customer_service.model.OfficeCategory;
import com.queueless.customer_service.model.OfficeProfile;
import com.queueless.customer_service.model.Provider;
import com.queueless.customer_service.model.TokenStatus;
import com.queueless.customer_service.model.VerificationStatus;
import com.queueless.customer_service.repository.OfficeProfileRepository;
import com.queueless.customer_service.repository.ProviderRepository;
import com.queueless.customer_service.repository.QueueTokenRepository;

@Service
@Transactional(readOnly = true)
public class CustomerOfficeService {

    private final OfficeProfileRepository profileRepository;
    private final QueueTokenRepository tokenRepository;
    private final ProviderRepository providerRepository;

    public CustomerOfficeService(
            OfficeProfileRepository profileRepository,
            QueueTokenRepository tokenRepository,
            ProviderRepository providerRepository) {
        this.profileRepository = profileRepository;
        this.tokenRepository = tokenRepository;
        this.providerRepository = providerRepository;
    }

    public List<Map<String, Object>> searchOffices(
            String query,
            OfficeCategory category,
            String city,
            VerificationStatus status,
            boolean includeAllStatus) {

        VerificationStatus filterStatus = includeAllStatus ? null : (status != null ? status : VerificationStatus.APPROVED);

        List<OfficeProfile> profiles = profileRepository.searchOffices(
                (query != null && !query.isBlank()) ? query.trim() : null,
                category,
                (city != null && !city.isBlank()) ? city.trim() : null,
                filterStatus
        );

        if (profiles.isEmpty() && filterStatus == VerificationStatus.APPROVED) {
            profiles = profileRepository.searchOffices(
                    (query != null && !query.isBlank()) ? query.trim() : null,
                    category,
                    (city != null && !city.isBlank()) ? city.trim() : null,
                    null
            );
        }

        List<Map<String, Object>> result = new ArrayList<>();
        for (OfficeProfile p : profiles) {
            result.add(formatOfficeSummary(p));
        }
        return result;
    }

    public List<Map<String, Object>> getFeaturedOffices() {
        List<OfficeProfile> profiles = profileRepository.findByVerificationStatus(VerificationStatus.APPROVED);
        if (profiles.isEmpty()) {
            profiles = profileRepository.findAll();
        }
        return profiles.stream()
                .limit(10)
                .map(this::formatOfficeSummary)
                .collect(Collectors.toList());
    }

    public Map<String, Object> getOfficeDetails(Long id) {
        OfficeProfile p = profileRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Office not found with ID: " + id));

        Map<String, Object> details = formatOfficeSummary(p);
        details.put("description", p.getDescription());
        details.put("phone", p.getPhone());
        details.put("state", p.getState());
        details.put("pincode", p.getPincode());
        details.put("tradeLicenseNumber", p.getTradeLicenseNumber());
        details.put("medicalRegistrationNumber", p.getMedicalRegistrationNumber());
        details.put("dailyMaxTokens", p.getDailyMaxTokens());
        return details;
    }

    public List<ProviderResponse> getOfficeProviders(Long officeId) {
        LocalDate today = LocalDate.now();
        LocalDateTime startOfDay = today.atStartOfDay();
        LocalDateTime endOfDay = today.atTime(LocalTime.MAX);
        long officeTokensToday = tokenRepository.countValidTokensTodayByOffice(officeId, startOfDay, endOfDay);
        OfficeProfile office = profileRepository.findById(officeId).orElse(null);
        int officeDailyMax = office != null ? office.getDailyMaxTokens() : 60;
        long officeRemaining = Math.max(0, officeDailyMax - officeTokensToday);

        return providerRepository.findByOfficeIdAndActiveTrueOrderByIdAsc(officeId).stream()
                .map(p -> mapProviderResponseWithCapacity(p, startOfDay, endOfDay, officeRemaining))
                .collect(Collectors.toList());
    }

    private ProviderResponse mapProviderResponseWithCapacity(Provider p, LocalDateTime startOfDay, LocalDateTime endOfDay, long officeRemaining) {
        ProviderResponse res = ProviderResponse.fromEntity(p);
        long providerTodayTokens = tokenRepository.countValidTokensTodayByProvider(p.getId(), startOfDay, endOfDay);
        res.setTodayTokensCount(providerTodayTokens);
        if (p.getDailyMaxTokens() != null) {
            long remaining = Math.max(0, p.getDailyMaxTokens() - providerTodayTokens);
            long effectiveRemaining = Math.min(remaining, officeRemaining);
            res.setRemainingCapacity(effectiveRemaining);
            res.setProviderFull(effectiveRemaining <= 0);
        } else {
            res.setRemainingCapacity(officeRemaining);
            res.setProviderFull(officeRemaining <= 0);
        }
        return res;
    }

    public Map<String, Object> formatOfficeSummary(OfficeProfile p) {
        Map<String, Object> map = new HashMap<>();
        map.put("id", p.getId());
        map.put("name", p.getUser() != null ? p.getUser().getName() : "Office");
        map.put("email", p.getUser() != null ? p.getUser().getEmail() : "");
        map.put("category", p.getCategory() != null ? p.getCategory().name() : "OTHER");
        map.put("address", p.getAddress());
        map.put("city", p.getCity());
        map.put("openingTime", p.getOpeningTime() != null ? p.getOpeningTime() : "09:00 AM");
        map.put("closingTime", p.getClosingTime() != null ? p.getClosingTime() : "08:00 PM");
        map.put("doctorName", p.getDoctorName());
        map.put("specialization", p.getSpecialization());
        map.put("salonType", p.getSalonType());
        map.put("verificationStatus", p.getVerificationStatus() != null ? p.getVerificationStatus().name() : "PENDING");

        Long waitingCount = tokenRepository.countByOfficeIdAndStatus(p.getId(), TokenStatus.WAITING);
        var activeToken = tokenRepository.findFirstByOfficeIdAndStatusInOrderBySequenceNumberAsc(
                p.getId(),
                List.of(TokenStatus.IN_SERVICE, TokenStatus.CALLED)
        ).orElse(null);

        map.put("waitingCount", waitingCount != null ? waitingCount : 0);
        map.put("activeToken", activeToken != null ? activeToken.getTokenNumber() : null);
        map.put("estimatedWaitMinutes", (waitingCount != null ? waitingCount : 0) * 12);
        return map;
    }
}
