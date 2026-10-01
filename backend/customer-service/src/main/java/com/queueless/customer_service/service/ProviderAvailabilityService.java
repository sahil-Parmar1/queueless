package com.queueless.customer_service.service;

import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.LocalTime;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.queueless.customer_service.model.Provider;
import com.queueless.customer_service.model.ProviderSchedule;

@Service
@Transactional(readOnly = true)
public class ProviderAvailabilityService {

    public boolean isProviderAvailableNow(Provider provider) {
        if (!Boolean.TRUE.equals(provider.getActive()) || !Boolean.TRUE.equals(provider.getOnDuty())) {
            return false;
        }

        DayOfWeek today = LocalDate.now().getDayOfWeek();
        LocalTime now = LocalTime.now();

        if (provider.getSchedules() == null || provider.getSchedules().isEmpty()) {
            return true;
        }

        return provider.getSchedules().stream()
                .anyMatch(s -> s.getDayOfWeek() == today
                        && !now.isBefore(s.getStartTime())
                        && !now.isAfter(s.getEndTime()));
    }
}
