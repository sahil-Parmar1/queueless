package com.queueless.office_service.provider;

import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.queueless.office_service.provider.dto.ProviderRequest;
import com.queueless.office_service.provider.dto.ProviderResponse;
import com.queueless.office_service.provider.dto.ProviderScheduleDto;
import com.queueless.office_service.queue.QueueTokenRepository;
import com.queueless.office_service.queue.TokenStatus;
import com.queueless.office_service.user.OfficeProfile;
import com.queueless.office_service.user.OfficeProfileRepository;

@Service
@Transactional
public class ProviderService {

    private final ProviderRepository providerRepository;
    private final ProviderScheduleRepository scheduleRepository;
    private final OfficeProfileRepository officeProfileRepository;
    private final QueueTokenRepository tokenRepository;

    public ProviderService(
            ProviderRepository providerRepository,
            ProviderScheduleRepository scheduleRepository,
            OfficeProfileRepository officeProfileRepository,
            QueueTokenRepository tokenRepository) {
        this.providerRepository = providerRepository;
        this.scheduleRepository = scheduleRepository;
        this.officeProfileRepository = officeProfileRepository;
        this.tokenRepository = tokenRepository;
    }

    /**
     * Get all providers belonging to an office.
     */
    @Transactional(readOnly = true)
    public List<ProviderResponse> getOfficeProviders(Long officeId) {
        return providerRepository.findByOfficeIdOrderByIdAsc(officeId).stream()
                .map(ProviderResponse::fromEntity)
                .collect(Collectors.toList());
    }

    /**
     * Get active providers of an office (for public customer view).
     */
    @Transactional(readOnly = true)
    public List<ProviderResponse> getPublicActiveOfficeProviders(Long officeId) {
        return providerRepository.findByOfficeIdAndActiveTrueOrderByIdAsc(officeId).stream()
                .map(ProviderResponse::fromEntity)
                .collect(Collectors.toList());
    }

    /**
     * Get details of a single provider with ownership verification.
     */
    @Transactional(readOnly = true)
    public ProviderResponse getProviderDetails(Long officeId, Long providerId) {
        Provider provider = getProviderOwnedByOffice(officeId, providerId);
        return ProviderResponse.fromEntity(provider);
    }

    /**
     * Create a new provider with working schedules for an office.
     */
    public ProviderResponse createProvider(Long officeId, ProviderRequest request) {
        OfficeProfile office = officeProfileRepository.findById(officeId)
                .orElseThrow(() -> new RuntimeException("Office profile not found with ID: " + officeId));

        validateProviderRequest(request);

        Provider provider = new Provider();
        provider.setOffice(office);
        provider.setName(request.getName().trim());
        provider.setDesignation(request.getDesignation() != null ? request.getDesignation().trim() : null);
        provider.setContactNumber(request.getContactNumber() != null ? request.getContactNumber().trim() : null);
        provider.setEmail(request.getEmail() != null ? request.getEmail().trim() : null);
        provider.setActive(request.getActive() != null ? request.getActive() : true);

        applySchedules(provider, request.getSchedules());

        Provider saved = providerRepository.save(provider);
        return ProviderResponse.fromEntity(saved);
    }

    /**
     * Update an existing provider and their schedules.
     */
    public ProviderResponse updateProvider(Long officeId, Long providerId, ProviderRequest request) {
        Provider provider = getProviderOwnedByOffice(officeId, providerId);
        validateProviderRequest(request);

        provider.setName(request.getName().trim());
        provider.setDesignation(request.getDesignation() != null ? request.getDesignation().trim() : null);
        provider.setContactNumber(request.getContactNumber() != null ? request.getContactNumber().trim() : null);
        provider.setEmail(request.getEmail() != null ? request.getEmail().trim() : null);
        if (request.getActive() != null) {
            provider.setActive(request.getActive());
        }

        if (request.getSchedules() != null) {
            provider.getSchedules().clear();
            applySchedules(provider, request.getSchedules());
        }

        Provider saved = providerRepository.save(provider);
        return ProviderResponse.fromEntity(saved);
    }

    /**
     * Activate or deactivate a provider.
     */
    public ProviderResponse setProviderActiveStatus(Long officeId, Long providerId, boolean active) {
        Provider provider = getProviderOwnedByOffice(officeId, providerId);
        provider.setActive(active);
        Provider saved = providerRepository.save(provider);
        return ProviderResponse.fromEntity(saved);
    }

    /**
     * Safely delete a provider. Rejects if active tokens exist, unlinks past tokens to preserve history.
     */
    public void deleteProvider(Long officeId, Long providerId) {
        Provider provider = getProviderOwnedByOffice(officeId, providerId);

        long activeTokens = tokenRepository.countByProviderIdAndStatusIn(
                providerId,
                List.of(TokenStatus.WAITING, TokenStatus.CALLED, TokenStatus.IN_SERVICE)
        );

        if (activeTokens > 0) {
            throw new IllegalStateException("Cannot delete provider with " + activeTokens
                    + " active token(s) in queue. Please complete or cancel those tokens first, or deactivate the provider instead.");
        }

        // Preserve token history while removing provider relation
        tokenRepository.detachProvider(providerId);

        providerRepository.delete(provider);
    }

    /**
     * Check if a provider is available right now for token creation.
     */
    @Transactional(readOnly = true)
    public boolean isProviderAvailableNow(Provider provider) {
        if (!Boolean.TRUE.equals(provider.getActive())) {
            return false;
        }

        DayOfWeek today = LocalDate.now().getDayOfWeek();
        LocalTime now = LocalTime.now();

        if (provider.getSchedules() == null || provider.getSchedules().isEmpty()) {
            return true; // If no specific schedule is configured, assume available during office hours
        }

        return provider.getSchedules().stream()
                .anyMatch(s -> s.getDayOfWeek() == today
                        && !now.isBefore(s.getStartTime())
                        && !now.isAfter(s.getEndTime()));
    }

    public Provider getProviderOwnedByOffice(Long officeId, Long providerId) {
        return providerRepository.findByIdAndOfficeId(providerId, officeId)
                .orElseThrow(() -> new RuntimeException("Provider not found or does not belong to your office (Provider ID: " + providerId + ")"));
    }

    private void validateProviderRequest(ProviderRequest request) {
        if (request.getName() == null || request.getName().trim().isBlank()) {
            throw new IllegalArgumentException("Provider name is required and cannot be blank");
        }

        if (request.getSchedules() != null && !request.getSchedules().isEmpty()) {
            Set<DayOfWeek> seenDays = new HashSet<>();
            for (ProviderScheduleDto dto : request.getSchedules()) {
                if (dto.getDayOfWeek() == null) {
                    throw new IllegalArgumentException("Working day (dayOfWeek) cannot be null");
                }
                if (!seenDays.add(dto.getDayOfWeek())) {
                    throw new IllegalArgumentException("Duplicate schedule for day: " + dto.getDayOfWeek());
                }

                LocalTime start = dto.parseStartTime();
                LocalTime end = dto.parseEndTime();

                if (start == null || end == null) {
                    throw new IllegalArgumentException("Both start time and end time must be specified for " + dto.getDayOfWeek());
                }

                if (!end.isAfter(start)) {
                    throw new IllegalArgumentException("End time (" + dto.getEndTime() + ") must be strictly after start time ("
                            + dto.getStartTime() + ") for " + dto.getDayOfWeek());
                }
            }
        }
    }

    private void applySchedules(Provider provider, List<ProviderScheduleDto> scheduleDtos) {
        if (scheduleDtos == null) return;
        List<ProviderSchedule> list = new ArrayList<>();
        for (ProviderScheduleDto dto : scheduleDtos) {
            ProviderSchedule ps = new ProviderSchedule();
            ps.setProvider(provider);
            ps.setDayOfWeek(dto.getDayOfWeek());
            ps.setStartTime(dto.parseStartTime());
            ps.setEndTime(dto.parseEndTime());
            list.add(ps);
        }
        provider.setSchedules(list);
    }
}
