package com.queueless.office_service.queue;

import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.crypto.password.PasswordEncoder;

import com.queueless.office_service.auth.JwtService;
import com.queueless.office_service.provider.Provider;
import com.queueless.office_service.provider.ProviderRepository;
import com.queueless.office_service.provider.ProviderService;
import com.queueless.office_service.provider.dto.ProviderQueueSettingsRequest;
import com.queueless.office_service.provider.dto.ProviderQueueSettingsResponse;
import com.queueless.office_service.user.OfficeCategory;
import com.queueless.office_service.user.OfficeProfile;
import com.queueless.office_service.user.OfficeProfileRepository;
import com.queueless.office_service.user.User;
import com.queueless.office_service.user.dto.OfficeQueueSettingsRequest;
import com.queueless.office_service.user.dto.OfficeQueueSettingsResponse;

@ExtendWith(MockitoExtension.class)
class ProviderQueueLimitServiceTest {

    @Mock
    private ProviderRepository providerRepository;

    @Mock
    private OfficeProfileRepository officeProfileRepository;

    @Mock
    private QueueTokenRepository tokenRepository;

    @Mock
    private PasswordEncoder passwordEncoder;

    @Mock
    private JwtService jwtService;

    @InjectMocks
    private ProviderService providerService;

    private OfficeProfile office;
    private Provider provider1;
    private User officeUser;

    @BeforeEach
    void setUp() {
        officeUser = new User();
        officeUser.setId(10L);
        officeUser.setName("Metropolis Hospital");

        office = new OfficeProfile();
        office.setId(1L);
        office.setOfficeId("OFF-HOSP1");
        office.setUser(officeUser);
        office.setCategory(OfficeCategory.CLINIC);
        office.setDailyMaxTokens(60);

        provider1 = new Provider();
        provider1.setId(101L);
        provider1.setName("Dr. Adams");
        provider1.setUsername("adams");
        provider1.setActive(true);
        provider1.setOffice(office);
        provider1.setDailyMaxTokens(25);
    }

    @Test
    @DisplayName("Office limit update: succeeds when valid positive integer")
    void updateOfficeQueueSettings_success() {
        when(officeProfileRepository.findById(1L)).thenReturn(Optional.of(office));
        when(providerRepository.sumDailyMaxTokensByOfficeExcept(1L, null)).thenReturn(25);
        when(tokenRepository.countValidTokensTodayByOffice(eq(1L), any(), any())).thenReturn(10L);

        OfficeQueueSettingsResponse res = providerService.updateOfficeQueueSettings(1L, new OfficeQueueSettingsRequest(80));

        assertNotNull(res);
        assertEquals(80, res.getDailyMaxTokens());
        assertEquals(10L, res.getTodayTokensCount());
        assertEquals(70L, res.getRemainingCapacity());
        assertFalse(res.isOfficeFull());
        verify(officeProfileRepository).save(office);
    }

    @Test
    @DisplayName("Office limit update: rejects non-positive limits")
    void updateOfficeQueueSettings_rejectZeroOrNegative() {
        assertThrows(IllegalArgumentException.class, () ->
                providerService.updateOfficeQueueSettings(1L, new OfficeQueueSettingsRequest(0))
        );
        assertThrows(IllegalArgumentException.class, () ->
                providerService.updateOfficeQueueSettings(1L, new OfficeQueueSettingsRequest(-5))
        );
    }

    @Test
    @DisplayName("Office limit update: rejects reducing below sum of existing provider limits")
    void updateOfficeQueueSettings_rejectLessThanAllocatedProviderLimits() {
        when(officeProfileRepository.findById(1L)).thenReturn(Optional.of(office));
        when(providerRepository.sumDailyMaxTokensByOfficeExcept(1L, null)).thenReturn(40);

        IllegalArgumentException ex = assertThrows(IllegalArgumentException.class, () ->
                providerService.updateOfficeQueueSettings(1L, new OfficeQueueSettingsRequest(30))
        );

        assertTrue(ex.getMessage().contains("Office daily limit cannot be less than total already allocated provider limits (40 tokens)"));
    }

    @Test
    @DisplayName("Provider limit update: succeeds within office limit and sum limits")
    void updateProviderQueueSettings_success() {
        when(providerRepository.findById(101L)).thenReturn(Optional.of(provider1));
        when(providerRepository.sumDailyMaxTokensByOfficeExcept(1L, 101L)).thenReturn(20);
        when(tokenRepository.countValidTokensTodayByProvider(eq(101L), any(), any())).thenReturn(5L);
        when(tokenRepository.countValidTokensTodayByOffice(eq(1L), any(), any())).thenReturn(12L);

        ProviderQueueSettingsResponse res = providerService.updateProviderQueueSettings(101L, new ProviderQueueSettingsRequest(30));

        assertNotNull(res);
        assertEquals(30, res.getProviderDailyMaxTokens());
        assertEquals(60, res.getOfficeDailyMaxTokens());
        assertEquals(5L, res.getProviderTodayTokensCount());
        assertEquals(25L, res.getProviderRemainingCapacity());
        assertFalse(res.isProviderFull());
        verify(providerRepository).save(provider1);
    }

    @Test
    @DisplayName("Provider limit update: rejects when limit exceeds office daily maximum")
    void updateProviderQueueSettings_rejectExceedsOfficeMax() {
        when(providerRepository.findById(101L)).thenReturn(Optional.of(provider1));

        IllegalArgumentException ex = assertThrows(IllegalArgumentException.class, () ->
                providerService.updateProviderQueueSettings(101L, new ProviderQueueSettingsRequest(75))
        );

        assertTrue(ex.getMessage().contains("cannot exceed office daily maximum of 60 tokens"));
    }

    @Test
    @DisplayName("Provider limit update: rejects when sum of provider limits exceeds office daily max")
    void updateProviderQueueSettings_rejectExceedsSumOfProviderLimits() {
        when(providerRepository.findById(101L)).thenReturn(Optional.of(provider1));
        // Other providers in office already allocated 45 tokens. Office max is 60 tokens.
        // Trying to set this provider to 25 -> 45 + 25 = 70 > 60.
        when(providerRepository.sumDailyMaxTokensByOfficeExcept(1L, 101L)).thenReturn(45);

        IllegalArgumentException ex = assertThrows(IllegalArgumentException.class, () ->
                providerService.updateProviderQueueSettings(101L, new ProviderQueueSettingsRequest(25))
        );

        assertTrue(ex.getMessage().contains("Total provider limits cannot exceed office maximum limit of 60 tokens"));
        assertTrue(ex.getMessage().contains("Available allocation for this provider: 15 tokens"));
    }
}
