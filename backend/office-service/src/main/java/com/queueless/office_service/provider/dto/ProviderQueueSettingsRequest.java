package com.queueless.office_service.provider.dto;

public class ProviderQueueSettingsRequest {

    private Integer dailyMaxTokens;

    public ProviderQueueSettingsRequest() {}

    public ProviderQueueSettingsRequest(Integer dailyMaxTokens) {
        this.dailyMaxTokens = dailyMaxTokens;
    }

    public Integer getDailyMaxTokens() {
        return dailyMaxTokens;
    }

    public void setDailyMaxTokens(Integer dailyMaxTokens) {
        this.dailyMaxTokens = dailyMaxTokens;
    }
}
