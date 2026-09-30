package com.queueless.office_service.queue;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.util.Collections;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertEquals;
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
class QueueDailyLimitTest {

    @Mock
    private QueueTokenRepository tokenRepository;

    @Mock
    private OfficeProfileRepository officeProfileRepository;

    @Mock
    private ProviderRepository providerRepository;

    @Mock
    private ProviderService providerService;

    @InjectMocks
    private QueueService queueService;

    private OfficeProfile office;
    private Provider provider;
    private User officeUser;

    @BeforeEach
    void setUp() {
        officeUser = new User();
        officeUser.setId(10L);
        officeUser.setName("Apex Dental Care");
        officeUser.setEmail("apex@example.com");

        office = new OfficeProfile();
        office.setId(1L);
        office.setOfficeId("OFF-TEST1");
        office.setUser(officeUser);
        office.setCategory(OfficeCategory.CLINIC);
        office.setDailyMaxTokens(50);

        provider = new Provider();
        provider.setId(101L);
        provider.setName("Dr. Sarah");
        provider.setUsername("drsarah");
        provider.setActive(true);
        provider.setOffice(office);
        provider.setDailyMaxTokens(20);
        provider.setSchedules(Collections.emptyList());
    }

    @Test
    @DisplayName("Should successfully book token when office and provider are under daily limit")
    void bookToken_successUnderLimits() {
        when(officeProfileRepository.findByIdForUpdate(1L)).thenReturn(Optional.of(office));
        when(tokenRepository.countValidTokensTodayByOffice(eq(1L), any(), any())).thenReturn(10L);
        when(providerRepository.findByIdAndOfficeId(101L, 1L)).thenReturn(Optional.of(provider));
        when(providerService.isProviderAvailableNow(provider)).thenReturn(true);
        when(tokenRepository.countValidTokensTodayByProvider(eq(101L), any(), any())).thenReturn(5L);
        when(tokenRepository.findMaxSequenceNumberToday(eq(1L), any())).thenReturn(10);
        when(tokenRepository.countByOfficeIdAndStatus(1L, TokenStatus.WAITING)).thenReturn(2L);
        when(tokenRepository.save(any(QueueToken.class))).thenAnswer(inv -> inv.getArgument(0));

        var result = queueService.bookToken(1L, 101L, 999L, "John Doe", "9876543210", "john@example.com");

        assertNotNull(result);
        assertEquals("C-011", result.get("tokenNumber"));
        assertEquals(11, result.get("sequenceNumber"));
        assertEquals(2L, result.get("peopleAhead"));
        assertEquals("WAITING", result.get("status"));
        assertEquals("Dr. Sarah", result.get("providerName"));

        // Verify pessimistic lock query was used
        verify(officeProfileRepository).findByIdForUpdate(1L);
    }

    @Test
    @DisplayName("Should reject token generation when office daily limit is reached")
    void bookToken_rejectionWhenOfficeLimitReached() {
        office.setDailyMaxTokens(15);
        when(officeProfileRepository.findByIdForUpdate(1L)).thenReturn(Optional.of(office));
        when(tokenRepository.countValidTokensTodayByOffice(eq(1L), any(), any())).thenReturn(15L);

        IllegalStateException ex = assertThrows(IllegalStateException.class, () ->
                queueService.bookToken(1L, 101L, 999L, "John Doe", "9876543210", "john@example.com")
        );

        assertTrue(ex.getMessage().contains("Office has reached its daily maximum limit of 15 tokens"));
    }

    @Test
    @DisplayName("Should reject token generation when provider daily limit is reached")
    void bookToken_rejectionWhenProviderLimitReached() {
        provider.setDailyMaxTokens(10);
        when(officeProfileRepository.findByIdForUpdate(1L)).thenReturn(Optional.of(office));
        when(tokenRepository.countValidTokensTodayByOffice(eq(1L), any(), any())).thenReturn(12L);
        when(providerRepository.findByIdAndOfficeId(101L, 1L)).thenReturn(Optional.of(provider));
        when(providerService.isProviderAvailableNow(provider)).thenReturn(true);
        when(tokenRepository.countValidTokensTodayByProvider(eq(101L), any(), any())).thenReturn(10L);

        IllegalStateException ex = assertThrows(IllegalStateException.class, () ->
                queueService.bookToken(1L, 101L, 999L, "John Doe", "9876543210", "john@example.com")
        );

        assertTrue(ex.getMessage().contains("Dr. Sarah has reached their daily maximum limit of 10 tokens"));
    }
}
