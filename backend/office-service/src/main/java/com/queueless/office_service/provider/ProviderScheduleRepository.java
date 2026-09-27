package com.queueless.office_service.provider;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface ProviderScheduleRepository extends JpaRepository<ProviderSchedule, Long> {

    List<ProviderSchedule> findByProviderIdOrderByDayOfWeekAsc(Long providerId);

    void deleteByProviderId(Long providerId);
}
