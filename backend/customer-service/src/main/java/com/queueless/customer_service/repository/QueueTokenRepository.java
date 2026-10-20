package com.queueless.customer_service.repository;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import com.queueless.customer_service.model.QueueToken;
import com.queueless.customer_service.model.TokenStatus;

@Repository
public interface QueueTokenRepository extends JpaRepository<QueueToken, Long> {

    List<QueueToken> findByOfficeIdAndStatusInOrderBySequenceNumberAsc(Long officeId, List<TokenStatus> statuses);

    List<QueueToken> findByCustomerIdAndStatusInOrderByBookedAtDesc(Long customerId, List<TokenStatus> statuses);

    List<QueueToken> findByCustomerEmailAndStatusInOrderByBookedAtDesc(String customerEmail, List<TokenStatus> statuses);

    List<QueueToken> findByCustomerIdOrderByBookedAtDesc(Long customerId);

    List<QueueToken> findByCustomerEmailOrderByBookedAtDesc(String customerEmail);

    Optional<QueueToken> findFirstByOfficeIdAndStatusOrderBySequenceNumberAsc(Long officeId, TokenStatus status);

    Optional<QueueToken> findFirstByOfficeIdAndStatusInOrderBySequenceNumberAsc(Long officeId, List<TokenStatus> statuses);

    Long countByOfficeIdAndStatus(Long officeId, TokenStatus status);

    Long countByOfficeIdAndStatusIn(Long officeId, List<TokenStatus> statuses);

    @Query("SELECT COUNT(t) FROM QueueToken t WHERE t.office.id = :officeId AND t.status = 'WAITING' AND t.sequenceNumber < :sequenceNumber")
    Long countTokensAheadOf(@Param("officeId") Long officeId, @Param("sequenceNumber") Integer sequenceNumber);

    @Query("SELECT COALESCE(MAX(t.sequenceNumber), 0) FROM QueueToken t WHERE t.office.id = :officeId AND t.bookedAt >= :startOfDay")
    Integer findMaxSequenceNumberToday(@Param("officeId") Long officeId, @Param("startOfDay") LocalDateTime startOfDay);

    @Query("SELECT COUNT(t) FROM QueueToken t WHERE t.office.id = :officeId AND t.bookedAt >= :startOfDay AND t.bookedAt <= :endOfDay AND t.status != 'CANCELLED'")
    long countValidTokensTodayByOffice(@Param("officeId") Long officeId, @Param("startOfDay") LocalDateTime startOfDay, @Param("endOfDay") LocalDateTime endOfDay);

    @Query("SELECT COUNT(t) FROM QueueToken t WHERE t.provider.id = :providerId AND t.bookedAt >= :startOfDay AND t.bookedAt <= :endOfDay AND t.status != 'CANCELLED'")
    long countValidTokensTodayByProvider(@Param("providerId") Long providerId, @Param("startOfDay") LocalDateTime startOfDay, @Param("endOfDay") LocalDateTime endOfDay);

    Optional<QueueToken> findFirstByProviderIdAndStatusInOrderBySequenceNumberAsc(Long providerId, List<TokenStatus> statuses);

    @Query("SELECT COUNT(t) FROM QueueToken t WHERE t.provider.id = :providerId AND t.status = 'WAITING' AND t.sequenceNumber < :sequenceNumber")
    Long countTokensAheadOfProvider(@Param("providerId") Long providerId, @Param("sequenceNumber") Integer sequenceNumber);

    @Query("SELECT AVG(t.serviceDurationMinutes) FROM QueueToken t WHERE t.office.id = :officeId AND t.status = com.queueless.customer_service.model.TokenStatus.COMPLETED AND t.serviceDurationMinutes IS NOT NULL AND t.serviceDurationMinutes > 0")
    Double findAvgServiceDurationMinutesByOffice(@Param("officeId") Long officeId);

    @Query("SELECT AVG(t.serviceDurationMinutes) FROM QueueToken t WHERE t.provider.id = :providerId AND t.status = com.queueless.customer_service.model.TokenStatus.COMPLETED AND t.serviceDurationMinutes IS NOT NULL AND t.serviceDurationMinutes > 0")
    Double findAvgServiceDurationMinutesByProvider(@Param("providerId") Long providerId);

    @Query("SELECT COUNT(t) FROM QueueToken t WHERE t.office.id = :officeId AND t.status = com.queueless.customer_service.model.TokenStatus.COMPLETED")
    Long countCompletedTokensByOffice(@Param("officeId") Long officeId);

    @Query("SELECT COUNT(t) FROM QueueToken t WHERE t.office.id = :officeId AND t.status = com.queueless.customer_service.model.TokenStatus.WAITING AND t.isPriority = true AND t.sequenceNumber < :sequenceNumber")
    Long countPriorityTokensAheadOfOffice(@Param("officeId") Long officeId, @Param("sequenceNumber") Integer sequenceNumber);

    @Query("SELECT COUNT(t) FROM QueueToken t WHERE t.provider.id = :providerId AND t.status = com.queueless.customer_service.model.TokenStatus.WAITING AND t.isPriority = true AND t.sequenceNumber < :sequenceNumber")
    Long countPriorityTokensAheadOfProvider(@Param("providerId") Long providerId, @Param("sequenceNumber") Integer sequenceNumber);

    @Query("SELECT COUNT(t) FROM QueueToken t WHERE t.office.id = :officeId AND t.status = com.queueless.customer_service.model.TokenStatus.WAITING AND (t.isPriority = true OR t.sequenceNumber < :sequenceNumber)")
    Long countStandardTokensAheadOfOffice(@Param("officeId") Long officeId, @Param("sequenceNumber") Integer sequenceNumber);

    @Query("SELECT COUNT(t) FROM QueueToken t WHERE t.provider.id = :providerId AND t.status = com.queueless.customer_service.model.TokenStatus.WAITING AND (t.isPriority = true OR t.sequenceNumber < :sequenceNumber)")
    Long countStandardTokensAheadOfProvider(@Param("providerId") Long providerId, @Param("sequenceNumber") Integer sequenceNumber);

    @Query("SELECT COUNT(t) FROM QueueToken t WHERE t.office.id = :officeId AND t.status = com.queueless.customer_service.model.TokenStatus.WAITING AND t.isPriority = true")
    Long countWaitingPriorityTokensInOffice(@Param("officeId") Long officeId);

    @Query("SELECT COUNT(t) FROM QueueToken t WHERE t.provider.id = :providerId AND t.status = com.queueless.customer_service.model.TokenStatus.WAITING AND t.isPriority = true")
    Long countWaitingPriorityTokensInProvider(@Param("providerId") Long providerId);

    Long countByProviderIdAndStatusIn(Long providerId, List<TokenStatus> statuses);
}
