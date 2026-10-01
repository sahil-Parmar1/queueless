package com.queueless.customer_service.repository;

import java.util.List;
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import com.queueless.customer_service.model.Provider;

@Repository
public interface ProviderRepository extends JpaRepository<Provider, Long> {

    List<Provider> findByOfficeIdOrderByIdAsc(Long officeId);

    List<Provider> findByOfficeIdAndActiveTrueOrderByIdAsc(Long officeId);

    Optional<Provider> findByIdAndOfficeId(Long id, Long officeId);

    Optional<Provider> findByOfficeIdAndUsername(Long officeId, String username);

    @Query("SELECT COALESCE(SUM(p.dailyMaxTokens), 0) FROM Provider p WHERE p.office.id = :officeId AND p.dailyMaxTokens IS NOT NULL")
    int sumDailyMaxTokensByOffice(@Param("officeId") Long officeId);

    @Query("SELECT COALESCE(SUM(p.dailyMaxTokens), 0) FROM Provider p WHERE p.office.id = :officeId AND p.id != :providerId AND p.dailyMaxTokens IS NOT NULL")
    int sumDailyMaxTokensByOfficeExcept(@Param("officeId") Long officeId, @Param("providerId") Long providerId);
}
