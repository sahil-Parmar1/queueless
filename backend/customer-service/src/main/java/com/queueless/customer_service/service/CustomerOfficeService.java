package com.queueless.customer_service.service;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.stream.Collectors;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.queueless.customer_service.dto.ProviderResponse;
import com.queueless.customer_service.model.CustomerFavoriteOffice;
import com.queueless.customer_service.model.OfficeCategory;
import com.queueless.customer_service.model.OfficeProfile;
import com.queueless.customer_service.model.Provider;
import com.queueless.customer_service.model.TokenStatus;
import com.queueless.customer_service.model.VerificationStatus;
import com.queueless.customer_service.repository.CustomerFavoriteOfficeRepository;
import com.queueless.customer_service.repository.OfficeProfileRepository;
import com.queueless.customer_service.repository.ProviderRepository;
import com.queueless.customer_service.repository.QueueTokenRepository;

@Service
@Transactional(readOnly = true)
public class CustomerOfficeService {

    private final OfficeProfileRepository profileRepository;
    private final QueueTokenRepository tokenRepository;
    private final ProviderRepository providerRepository;
    private final CustomerFavoriteOfficeRepository favoriteRepository;

    public CustomerOfficeService(
            OfficeProfileRepository profileRepository,
            QueueTokenRepository tokenRepository,
            ProviderRepository providerRepository,
            CustomerFavoriteOfficeRepository favoriteRepository) {
        this.profileRepository = profileRepository;
        this.tokenRepository = tokenRepository;
        this.providerRepository = providerRepository;
        this.favoriteRepository = favoriteRepository;
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
        map.put("isOpen", p.getIsOpen());
        map.put("latitude", p.getLatitude());
        map.put("longitude", p.getLongitude());

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

    @Transactional
    public Map<String, Object> toggleFavorite(Long customerId, String email, Long officeId) {
        OfficeProfile office = profileRepository.findById(officeId)
                .orElseThrow(() -> new IllegalArgumentException("Office not found with id: " + officeId));

        Optional<CustomerFavoriteOffice> existing = Optional.empty();
        if (customerId != null) {
            existing = favoriteRepository.findByCustomerIdAndOfficeId(customerId, officeId);
        }
        if (existing.isEmpty() && email != null && !email.isBlank()) {
            existing = favoriteRepository.findByCustomerEmailAndOfficeId(email.trim(), officeId);
        }

        boolean isFavorite;
        if (existing.isPresent()) {
            favoriteRepository.delete(existing.get());
            isFavorite = false;
        } else {
            CustomerFavoriteOffice fav = new CustomerFavoriteOffice(customerId, email, office);
            favoriteRepository.save(fav);
            isFavorite = true;
        }

        Map<String, Object> res = new HashMap<>();
        res.put("success", true);
        res.put("officeId", officeId);
        res.put("isFavorite", isFavorite);
        return res;
    }

    public List<Long> getFavoriteOfficeIds(Long customerId, String email) {
        if (customerId != null) {
            List<Long> ids = favoriteRepository.findFavoriteOfficeIdsByCustomerId(customerId);
            if (!ids.isEmpty()) return ids;
        }
        if (email != null && !email.isBlank()) {
            return favoriteRepository.findFavoriteOfficeIdsByCustomerEmail(email.trim());
        }
        return List.of();
    }

    public List<Map<String, Object>> getFavoriteOffices(Long customerId, String email) {
        List<CustomerFavoriteOffice> favs = List.of();
        if (customerId != null) {
            favs = favoriteRepository.findByCustomerIdOrderByCreatedAtDesc(customerId);
        }
        if (favs.isEmpty() && email != null && !email.isBlank()) {
            favs = favoriteRepository.findByCustomerEmailOrderByCreatedAtDesc(email.trim());
        }

        List<Map<String, Object>> result = new ArrayList<>();
        for (CustomerFavoriteOffice f : favs) {
            if (f.getOffice() != null) {
                Map<String, Object> map = formatOfficeSummary(f.getOffice());
                map.put("isFavorite", true);
                result.add(map);
            }
        }
        return result;
    }

    public boolean isFavorite(Long customerId, String email, Long officeId) {
        if (customerId != null && favoriteRepository.existsByCustomerIdAndOfficeId(customerId, officeId)) {
            return true;
        }
        if (email != null && !email.isBlank() && favoriteRepository.existsByCustomerEmailAndOfficeId(email.trim(), officeId)) {
            return true;
        }
        return false;
    }
}
