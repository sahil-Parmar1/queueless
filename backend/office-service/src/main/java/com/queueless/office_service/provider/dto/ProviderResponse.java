package com.queueless.office_service.provider.dto;

import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.time.format.TextStyle;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Locale;
import java.util.stream.Collectors;

import com.queueless.office_service.provider.Provider;
import com.queueless.office_service.provider.ProviderSchedule;

public class ProviderResponse {

    private Long id;
    private Long officeId;
    private String officeCode;
    private String officeName;
    private String name;
    private String username;
    private String designation;
    private String contactNumber;
    private String email;
    private Boolean active;
    private Boolean onDuty;
    private List<ProviderScheduleDto> schedules = new ArrayList<>();
    private boolean availableNow;
    private String todayWorkingHours;
    private String workingDaysSummary;
    private Integer dailyMaxTokens;
    private Long todayTokensCount;
    private Long remainingCapacity;
    private Boolean providerFull;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;

    public static ProviderResponse fromEntity(Provider provider) {
        ProviderResponse res = new ProviderResponse();
        res.setId(provider.getId());
        if (provider.getOffice() != null) {
            res.setOfficeId(provider.getOffice().getId());
            res.setOfficeCode(provider.getOffice().getOfficeId());
            if (provider.getOffice().getUser() != null) {
                res.setOfficeName(provider.getOffice().getUser().getName());
            }
        }
        res.setName(provider.getName());
        res.setUsername(provider.getUsername());
        res.setDesignation(provider.getDesignation());
        res.setContactNumber(provider.getContactNumber());
        res.setEmail(provider.getEmail());
        res.setActive(provider.getActive());
        res.setOnDuty(provider.getOnDuty() != null ? provider.getOnDuty() : true);
        res.setDailyMaxTokens(provider.getDailyMaxTokens());
        res.setCreatedAt(provider.getCreatedAt());
        res.setUpdatedAt(provider.getUpdatedAt());

        List<ProviderScheduleDto> scheduleDtos = new ArrayList<>();
        if (provider.getSchedules() != null) {
            scheduleDtos = provider.getSchedules().stream()
                    .sorted(Comparator.comparing(ProviderSchedule::getDayOfWeek))
                    .map(s -> new ProviderScheduleDto(s.getDayOfWeek(), s.getStartTime(), s.getEndTime()))
                    .collect(Collectors.toList());
        }
        res.setSchedules(scheduleDtos);

        // Compute today's availability
        DayOfWeek today = LocalDate.now().getDayOfWeek();
        LocalTime now = LocalTime.now();

        ProviderSchedule todaySchedule = null;
        if (provider.getSchedules() != null) {
            todaySchedule = provider.getSchedules().stream()
                    .filter(s -> s.getDayOfWeek() == today)
                    .findFirst()
                    .orElse(null);
        }

        boolean isWorkingToday = todaySchedule != null;
        boolean withinHours = isWorkingToday && !now.isBefore(todaySchedule.getStartTime()) && !now.isAfter(todaySchedule.getEndTime());
        res.setAvailableNow(Boolean.TRUE.equals(provider.getActive()) && Boolean.TRUE.equals(res.getOnDuty()) && withinHours);

        if (todaySchedule != null) {
            res.setTodayWorkingHours(todaySchedule.getStartTime().toString().substring(0, 5) + " - " + todaySchedule.getEndTime().toString().substring(0, 5));
        } else {
            res.setTodayWorkingHours("Off Today");
        }

        if (scheduleDtos.isEmpty()) {
            res.setWorkingDaysSummary("No schedule configured");
        } else {
            String days = scheduleDtos.stream()
                    .map(s -> s.getDayOfWeek().getDisplayName(TextStyle.SHORT, Locale.ENGLISH))
                    .collect(Collectors.joining(", "));
            res.setWorkingDaysSummary(days);
        }

        return res;
    }

    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public Long getOfficeId() {
        return officeId;
    }

    public void setOfficeId(Long officeId) {
        this.officeId = officeId;
    }

    public String getOfficeCode() {
        return officeCode;
    }

    public void setOfficeCode(String officeCode) {
        this.officeCode = officeCode;
    }

    public String getOfficeName() {
        return officeName;
    }

    public void setOfficeName(String officeName) {
        this.officeName = officeName;
    }

    public String getName() {
        return name;
    }

    public void setName(String name) {
        this.name = name;
    }

    public String getUsername() {
        return username;
    }

    public void setUsername(String username) {
        this.username = username;
    }

    public String getDesignation() {
        return designation;
    }

    public void setDesignation(String designation) {
        this.designation = designation;
    }

    public String getContactNumber() {
        return contactNumber;
    }

    public void setContactNumber(String contactNumber) {
        this.contactNumber = contactNumber;
    }

    public String getEmail() {
        return email;
    }

    public void setEmail(String email) {
        this.email = email;
    }

    public Boolean getActive() {
        return active;
    }

    public void setActive(Boolean active) {
        this.active = active;
    }

    public List<ProviderScheduleDto> getSchedules() {
        return schedules;
    }

    public void setSchedules(List<ProviderScheduleDto> schedules) {
        this.schedules = schedules;
    }

    public boolean isAvailableNow() {
        return availableNow;
    }

    public void setAvailableNow(boolean availableNow) {
        this.availableNow = availableNow;
    }

    public String getTodayWorkingHours() {
        return todayWorkingHours;
    }

    public void setTodayWorkingHours(String todayWorkingHours) {
        this.todayWorkingHours = todayWorkingHours;
    }

    public String getWorkingDaysSummary() {
        return workingDaysSummary;
    }

    public void setWorkingDaysSummary(String workingDaysSummary) {
        this.workingDaysSummary = workingDaysSummary;
    }

    public LocalDateTime getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(LocalDateTime createdAt) {
        this.createdAt = createdAt;
    }

    public LocalDateTime getUpdatedAt() {
        return updatedAt;
    }

    public void setUpdatedAt(LocalDateTime updatedAt) {
        this.updatedAt = updatedAt;
    }

    public Integer getDailyMaxTokens() {
        return dailyMaxTokens;
    }

    public void setDailyMaxTokens(Integer dailyMaxTokens) {
        this.dailyMaxTokens = dailyMaxTokens;
    }

    public Long getTodayTokensCount() {
        return todayTokensCount;
    }

    public void setTodayTokensCount(Long todayTokensCount) {
        this.todayTokensCount = todayTokensCount;
    }

    public Long getRemainingCapacity() {
        return remainingCapacity;
    }

    public void setRemainingCapacity(Long remainingCapacity) {
        this.remainingCapacity = remainingCapacity;
    }

    public Boolean getProviderFull() {
        return providerFull;
    }

    public void setProviderFull(Boolean providerFull) {
        this.providerFull = providerFull;
    }

    public Boolean getOnDuty() {
        return onDuty;
    }

    public void setOnDuty(Boolean onDuty) {
        this.onDuty = onDuty;
    }
}
