package com.queueless.office_service.queue;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.util.Collections;
import java.util.Optional;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.atomic.AtomicInteger;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import static org.mockito.Mockito.when;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;

import com.queueless.office_service.provider.Provider;
import com.queueless.office_service.provider.ProviderRepository;
import com.queueless.office_service.provider.ProviderService;
import com.queueless.office_service.user.OfficeCategory;
import com.queueless.office_service.user.OfficeProfile;
import com.queueless.office_service.user.OfficeProfileRepository;
import com.queueless.office_service.user.User;

@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class ConcurrentQueueBookingTest {

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

    @BeforeEach
    void setUp() {
        User officeUser = new User();
        officeUser.setId(10L);
        officeUser.setName("Nova Health");

        office = new OfficeProfile();
        office.setId(1L);
        office.setOfficeId("OFF-NOVA1");
        office.setUser(officeUser);
        office.setCategory(OfficeCategory.CLINIC);
        office.setDailyMaxTokens(5); // Only 5 tokens allowed today

        provider = new Provider();
        provider.setId(201L);
        provider.setName("Dr. Robert");
        provider.setUsername("robert");
        provider.setActive(true);
        provider.setOffice(office);
        provider.setDailyMaxTokens(5);
        provider.setSchedules(Collections.emptyList());
    }

    @Test
    @DisplayName("Simulate 20 concurrent requests against daily limit of 5: exactly 5 succeed, 15 rejected")
    void testConcurrentBookingsNeverExceedLimit() throws InterruptedException {
        int limit = 5;
        int totalRequests = 20;

        AtomicInteger currentTokensCount = new AtomicInteger(0);
        AtomicInteger successCount = new AtomicInteger(0);
        AtomicInteger rejectedCount = new AtomicInteger(0);

        // Office findByIdForUpdate is serialized per office
        when(officeProfileRepository.findByIdForUpdate(1L)).thenReturn(Optional.of(office));
        when(providerRepository.findByIdAndOfficeId(201L, 1L)).thenReturn(Optional.of(provider));
        when(providerService.isProviderAvailableNow(provider)).thenReturn(true);

        // Synchronized mock to simulate database count under the serialized pessimistic lock
        when(tokenRepository.countValidTokensTodayByOffice(eq(1L), any(), any()))
                .thenAnswer(inv -> (long) currentTokensCount.get());

        when(tokenRepository.countValidTokensTodayByProvider(eq(201L), any(), any()))
                .thenAnswer(inv -> (long) currentTokensCount.get());

        when(tokenRepository.findMaxSequenceNumberToday(eq(1L), any()))
                .thenAnswer(inv -> currentTokensCount.get());

        when(tokenRepository.countByOfficeIdAndStatus(eq(1L), any()))
                .thenReturn(0L);

        when(tokenRepository.save(any(QueueToken.class))).thenAnswer(inv -> {
            currentTokensCount.incrementAndGet();
            return inv.getArgument(0);
        });

        ExecutorService executor = Executors.newFixedThreadPool(10);
        CountDownLatch startGate = new CountDownLatch(1);
        CountDownLatch endGate = new CountDownLatch(totalRequests);

        for (int i = 0; i < totalRequests; i++) {
            final int index = i;
            executor.submit(() -> {
                try {
                    startGate.await();
                    // Serialized by pessimistic lock in real DB; simulate synchronized block
                    synchronized (office) {
                        queueService.bookToken(1L, 201L, (long) index, "Customer " + index, "1234567890", "cust" + index + "@test.com");
                    }
                    successCount.incrementAndGet();
                } catch (IllegalStateException e) {
                    if (e.getMessage().contains("daily maximum limit")) {
                        rejectedCount.incrementAndGet();
                    }
                } catch (Exception e) {
                    e.printStackTrace();
                } finally {
                    endGate.countDown();
                }
            });
        }

        startGate.countDown(); // Start all threads at once
        endGate.await();
        executor.shutdown();

        assertEquals(limit, successCount.get(), "Exactly 5 requests must succeed");
        assertEquals(totalRequests - limit, rejectedCount.get(), "Exactly 15 requests must be rejected due to limit");
        assertEquals(limit, currentTokensCount.get(), "Current tokens count must equal daily limit");
    }
}
