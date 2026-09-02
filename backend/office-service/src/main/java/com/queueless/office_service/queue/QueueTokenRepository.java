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

    Optional<QueueToken> findFirstByOfficeIdAndStatusInOrderBySequenceNumberAsc(Long officeId, List<TokenStatus> statuses);

    Long countByOfficeIdAndStatus(Long officeId, TokenStatus status);

    Long countByOfficeIdAndStatusIn(Long officeId, List<TokenStatus> statuses);

    @Query("SELECT COUNT(t) FROM QueueToken t WHERE t.office.id = :officeId AND t.status = 'WAITING' AND t.sequenceNumber < :sequenceNumber")
    Long countTokensAheadOf(@Param("officeId") Long officeId, @Param("sequenceNumber") Integer sequenceNumber);

    @Query("SELECT COALESCE(MAX(t.sequenceNumber), 0) FROM QueueToken t WHERE t.office.id = :officeId AND t.bookedAt >= :startOfDay")
    Integer findMaxSequenceNumberToday(@Param("officeId") Long officeId, @Param("startOfDay") LocalDateTime startOfDay);

    List<QueueToken> findByOfficeIdAndBookedAtBetweenOrderBySequenceNumberAsc(Long officeId, LocalDateTime start, LocalDateTime end);

    List<QueueToken> findByOfficeIdOrderByBookedAtDesc(Long officeId);
}
