package com.queueless.office_service.provider;

import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;

import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.queueless.office_service.auth.JwtService;
import com.queueless.office_service.provider.dto.ProviderLoginRequest;
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
    private final PasswordEncoder passwordEncoder;
    private final JwtService jwtService;

    public ProviderService(
            ProviderRepository providerRepository,
            ProviderScheduleRepository scheduleRepository,
            OfficeProfileRepository officeProfileRepository,
            QueueTokenRepository tokenRepository,
            PasswordEncoder passwordEncoder,
            JwtService jwtService) {
        this.providerRepository = providerRepository;
        this.scheduleRepository = scheduleRepository;
        this.officeProfileRepository = officeProfileRepository;
        this.tokenRepository = tokenRepository;
        this.passwordEncoder = passwordEncoder;
        this.jwtService = jwtService;
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
     * Create a new provider with working schedules and credentials for an office.
     */
    public ProviderResponse createProvider(Long officeId, ProviderRequest request) {
        OfficeProfile office = officeProfileRepository.findById(officeId)
                .orElseThrow(() -> new RuntimeException("Office profile not found with ID: " + officeId));

        validateProviderRequest(request);

        // Validate and set username
        if (request.getUsername() == null || request.getUsername().trim().isBlank()) {
            throw new IllegalArgumentException("Provider username is required");
        }
        String username = request.getUsername().trim().toLowerCase();
        if (providerRepository.existsByOfficeIdAndUsernameIgnoreCase(officeId, username)) {
            throw new IllegalArgumentException("Username '" + username + "' is already taken in your office");
        }

        // Validate and encode password
        if (request.getPassword() == null || request.getPassword().trim().length() < 4) {
            throw new IllegalArgumentException("Provider password is required (minimum 4 characters)");
        }

        Provider provider = new Provider();
        provider.setOffice(office);
        provider.setName(request.getName().trim());
        provider.setUsername(username);
        provider.setPassword(passwordEncoder.encode(request.getPassword().trim()));
        provider.setDesignation(request.getDesignation() != null ? request.getDesignation().trim() : null);
        provider.setContactNumber(request.getContactNumber() != null ? request.getContactNumber().trim() : null);
        provider.setEmail(request.getEmail() != null ? request.getEmail().trim() : null);
        provider.setActive(request.getActive() != null ? request.getActive() : true);

        applySchedules(provider, request.getSchedules());

        Provider saved = providerRepository.save(provider);
        return ProviderResponse.fromEntity(saved);
    }

    /**
     * Update an existing provider and their schedules/credentials.
     */
    public ProviderResponse updateProvider(Long officeId, Long providerId, ProviderRequest request) {
        Provider provider = getProviderOwnedByOffice(officeId, providerId);
        validateProviderRequest(request);

        provider.setName(request.getName().trim());

        if (request.getUsername() != null && !request.getUsername().trim().isBlank()) {
            String newUsername = request.getUsername().trim().toLowerCase();
            if (!newUsername.equalsIgnoreCase(provider.getUsername()) &&
                    providerRepository.existsByOfficeIdAndUsernameIgnoreCase(officeId, newUsername)) {
                throw new IllegalArgumentException("Username '" + newUsername + "' is already taken in your office");
            }
            provider.setUsername(newUsername);
        }

        if (request.getPassword() != null && !request.getPassword().trim().isBlank()) {
            if (request.getPassword().trim().length() < 4) {
                throw new IllegalArgumentException("Password must be at least 4 characters");
            }
            provider.setPassword(passwordEncoder.encode(request.getPassword().trim()));
        }

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
     * Authenticate provider with office ID, username, and password.
     */
    public java.util.Map<String, Object> loginProvider(ProviderLoginRequest request) {
        if (request.getOfficeId() == null || request.getOfficeId().trim().isBlank()
                || request.getUsername() == null || request.getUsername().trim().isBlank()
                || request.getPassword() == null || request.getPassword().trim().isBlank()) {
            throw new org.springframework.web.server.ResponseStatusException(
                    org.springframework.http.HttpStatus.BAD_REQUEST, "Office ID, username, and password are required");
        }

        String officeCode = request.getOfficeId().trim().toUpperCase();
        String username = request.getUsername().trim().toLowerCase();

        // 1. Find office by officeId
        OfficeProfile office = officeProfileRepository.findByOfficeId(officeCode)
                .or(() -> officeProfileRepository.findByUserOfficeId(officeCode))
                .orElseThrow(() -> new org.springframework.web.server.ResponseStatusException(
                        org.springframework.http.HttpStatus.UNAUTHORIZED, "Invalid Office ID or credentials"));

        // 2. Find provider belonging to this office
        Provider provider = providerRepository.findByOfficeIdAndUsernameIgnoreCase(office.getId(), username)
                .orElseThrow(() -> new org.springframework.web.server.ResponseStatusException(
                        org.springframework.http.HttpStatus.UNAUTHORIZED, "Invalid Office ID or credentials"));

        // 3. Verify active status
        if (!Boolean.TRUE.equals(provider.getActive())) {
            throw new org.springframework.web.server.ResponseStatusException(
                    org.springframework.http.HttpStatus.FORBIDDEN, "Provider account is deactivated. Please contact your office administrator.");
        }

        // 4. Verify password
        if (provider.getPassword() == null || !passwordEncoder.matches(request.getPassword().trim(), provider.getPassword())) {
            throw new org.springframework.web.server.ResponseStatusException(
                    org.springframework.http.HttpStatus.UNAUTHORIZED, "Invalid Office ID or credentials");
        }

        // 5. Generate JWT token
        String token = jwtService.generateProviderToken(provider, office.getOfficeId());

        return java.util.Map.of(
                "token", token,
                "role", "PROVIDER",
                "provider", ProviderResponse.fromEntity(provider)
        );
    }

    /**
     * Get details of currently authenticated provider.
     */
    @Transactional(readOnly = true)
    public ProviderResponse getCurrentProviderDetails(Long providerId) {
        Provider provider = providerRepository.findById(providerId)
                .orElseThrow(() -> new org.springframework.web.server.ResponseStatusException(
                        org.springframework.http.HttpStatus.NOT_FOUND, "Provider not found"));
        return ProviderResponse.fromEntity(provider);
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
