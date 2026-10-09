package com.queueless.office_service.queue;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

@Repository
public interface QueueTokenRepository extends JpaRepository<QueueToken, Long> {

    List<QueueToken> findByOfficeIdAndStatusInOrderBySequenceNumberAsc(Long officeId, List<TokenStatus> statuses);

    List<QueueToken> findByCustomerIdAndStatusInOrderByBookedAtDesc(Long customerId, List<TokenStatus> statuses);

    List<QueueToken> findByCustomerEmailAndStatusInOrderByBookedAtDesc(String customerEmail, List<TokenStatus> statuses);

    List<QueueToken> findByCustomerIdOrderByBookedAtDesc(Long customerId);

    List<QueueToken> findByCustomerEmailOrderByBookedAtDesc(String customerEmail);

    Optional<QueueToken> findFirstByOfficeIdAndStatusOrderBySequenceNumberAsc(Long officeId, TokenStatus status);

    Optional<QueueToken> findFirstByOfficeIdAndStatusOrderByIsPriorityDescSequenceNumberAsc(Long officeId, TokenStatus status);

    Optional<QueueToken> findFirstByOfficeIdAndStatusInOrderBySequenceNumberAsc(Long officeId, List<TokenStatus> statuses);

    Long countByOfficeIdAndStatus(Long officeId, TokenStatus status);

    Long countByOfficeIdAndStatusIn(Long officeId, List<TokenStatus> statuses);

    @Query("SELECT COUNT(t) FROM QueueToken t WHERE t.office.id = :officeId AND t.status = 'WAITING' AND t.sequenceNumber < :sequenceNumber")
    Long countTokensAheadOf(@Param("officeId") Long officeId, @Param("sequenceNumber") Integer sequenceNumber);

    @Query("SELECT COALESCE(MAX(t.sequenceNumber), 0) FROM QueueToken t WHERE t.office.id = :officeId AND t.bookedAt >= :startOfDay")
    Integer findMaxSequenceNumberToday(@Param("officeId") Long officeId, @Param("startOfDay") LocalDateTime startOfDay);

    List<QueueToken> findByOfficeIdAndBookedAtBetweenOrderBySequenceNumberAsc(Long officeId, LocalDateTime start, LocalDateTime end);

    List<QueueToken> findByOfficeIdOrderByBookedAtDesc(Long officeId);

    long countByProviderIdAndStatusIn(Long providerId, List<TokenStatus> statuses);

    List<QueueToken> findByProviderIdAndStatusIn(Long providerId, List<TokenStatus> statuses);

    @org.springframework.data.jpa.repository.Modifying
    @Query("UPDATE QueueToken t SET t.provider = null WHERE t.provider.id = :providerId")
    void detachProvider(@Param("providerId") Long providerId);

    @Query("SELECT COUNT(t) FROM QueueToken t WHERE t.office.id = :officeId AND t.bookedAt >= :startOfDay AND t.bookedAt <= :endOfDay AND t.status != 'CANCELLED'")
    long countValidTokensTodayByOffice(@Param("officeId") Long officeId, @Param("startOfDay") LocalDateTime startOfDay, @Param("endOfDay") LocalDateTime endOfDay);

    @Query("SELECT COUNT(t) FROM QueueToken t WHERE t.provider.id = :providerId AND t.bookedAt >= :startOfDay AND t.bookedAt <= :endOfDay AND t.status != 'CANCELLED'")
    long countValidTokensTodayByProvider(@Param("providerId") Long providerId, @Param("startOfDay") LocalDateTime startOfDay, @Param("endOfDay") LocalDateTime endOfDay);

    Optional<QueueToken> findFirstByProviderIdAndStatusInOrderBySequenceNumberAsc(Long providerId, List<TokenStatus> statuses);

    Optional<QueueToken> findFirstByProviderIdAndStatusOrderBySequenceNumberAsc(Long providerId, TokenStatus status);

    List<QueueToken> findByProviderIdAndStatusInOrderBySequenceNumberAsc(Long providerId, List<TokenStatus> statuses);

    List<QueueToken> findByProviderIdAndBookedAtBetweenOrderBySequenceNumberAsc(Long providerId, LocalDateTime start, LocalDateTime end);

    @Query("SELECT COUNT(t) FROM QueueToken t WHERE t.provider.id = :providerId AND t.status = 'WAITING' AND t.sequenceNumber < :sequenceNumber")
    Long countTokensAheadOfProvider(@Param("providerId") Long providerId, @Param("sequenceNumber") Integer sequenceNumber);

    List<QueueToken> findByOfficeIdAndProviderIsNullAndStatusInOrderBySequenceNumberAsc(Long officeId, List<TokenStatus> statuses);

    Long countByOfficeIdAndProviderIsNullAndStatus(Long officeId, TokenStatus status);

    List<QueueToken> findByRequestedProviderIdAndRequestStatusAndStatusInOrderBySequenceNumberAsc(
            Long requestedProviderId, String requestStatus, List<TokenStatus> statuses);

    Optional<QueueToken> findFirstByProviderIdAndStatusOrderByIsPriorityDescSequenceNumberAsc(Long providerId, TokenStatus status);

    List<QueueToken> findByProviderIdAndStatusInOrderByIsPriorityDescSequenceNumberAsc(Long providerId, List<TokenStatus> statuses);

    List<QueueToken> findByOfficeIdAndPriorityStatusAndStatusInOrderByPriorityRequestedAtAsc(
            Long officeId, String priorityStatus, List<TokenStatus> statuses);

    List<QueueToken> findByRequestedProviderIdAndPriorityStatusAndStatusInOrderByPriorityRequestedAtAsc(
            Long requestedProviderId, String priorityStatus, List<TokenStatus> statuses);
}
