package com.queueless.office_service.provider.dto;

import java.time.DayOfWeek;
import java.time.LocalTime;
import java.time.format.DateTimeFormatter;

public class ProviderScheduleDto {

    private DayOfWeek dayOfWeek;
    private String startTime; // "HH:mm" or "HH:mm:ss"
    private String endTime;   // "HH:mm" or "HH:mm:ss"

    public ProviderScheduleDto() {
    }

    public ProviderScheduleDto(DayOfWeek dayOfWeek, String startTime, String endTime) {
        this.dayOfWeek = dayOfWeek;
        this.startTime = startTime;
        this.endTime = endTime;
    }

    public ProviderScheduleDto(DayOfWeek dayOfWeek, LocalTime start, LocalTime end) {
        this.dayOfWeek = dayOfWeek;
        this.startTime = start != null ? start.format(DateTimeFormatter.ofPattern("HH:mm")) : null;
        this.endTime = end != null ? end.format(DateTimeFormatter.ofPattern("HH:mm")) : null;
    }

    public DayOfWeek getDayOfWeek() {
        return dayOfWeek;
    }

    public void setDayOfWeek(DayOfWeek dayOfWeek) {
        this.dayOfWeek = dayOfWeek;
    }

    public String getStartTime() {
        return startTime;
    }

    public void setStartTime(String startTime) {
        this.startTime = startTime;
    }

    public String getEndTime() {
        return endTime;
    }

    public void setEndTime(String endTime) {
        this.endTime = endTime;
    }

    public LocalTime parseStartTime() {
        if (startTime == null || startTime.isBlank()) return null;
        return LocalTime.parse(startTime.trim().length() == 5 ? startTime.trim() + ":00" : startTime.trim());
    }

    public LocalTime parseEndTime() {
        if (endTime == null || endTime.isBlank()) return null;
        return LocalTime.parse(endTime.trim().length() == 5 ? endTime.trim() + ":00" : endTime.trim());
    }
}
