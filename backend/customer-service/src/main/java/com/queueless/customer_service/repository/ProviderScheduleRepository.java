package com.queueless.customer_service.repository;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import com.queueless.customer_service.model.ProviderSchedule;

@Repository
public interface ProviderScheduleRepository extends JpaRepository<ProviderSchedule, Long> {
    List<ProviderSchedule> findByProviderId(Long providerId);
}
