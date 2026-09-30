package com.queueless.office_service.user.dto;

public class OfficeQueueSettingsRequest {

    private Integer dailyMaxTokens;

    public OfficeQueueSettingsRequest() {}

    public OfficeQueueSettingsRequest(Integer dailyMaxTokens) {
        this.dailyMaxTokens = dailyMaxTokens;
    }

    public Integer getDailyMaxTokens() {
        return dailyMaxTokens;
    }

    public void setDailyMaxTokens(Integer dailyMaxTokens) {
        this.dailyMaxTokens = dailyMaxTokens;
    }
}
