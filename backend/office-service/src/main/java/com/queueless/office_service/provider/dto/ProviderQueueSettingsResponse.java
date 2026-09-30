package com.queueless.office_service.provider.dto;

public class ProviderQueueSettingsResponse {
    private Long providerId;
    private String providerName;
    private String username;
    private Long officeId;
    private String officeCode;
    private Integer officeDailyMaxTokens;
    private Integer providerDailyMaxTokens;
    private long providerTodayTokensCount;
    private long officeTodayTokensCount;
    private long providerRemainingCapacity;
    private long officeRemainingCapacity;
    private long effectiveRemainingCapacity;
    private boolean providerFull;
    private boolean officeFull;

    public ProviderQueueSettingsResponse() {}

    public ProviderQueueSettingsResponse(Long providerId, String providerName, String username,
                                         Long officeId, String officeCode, Integer officeDailyMaxTokens,
                                         Integer providerDailyMaxTokens, long providerTodayTokensCount,
                                         long officeTodayTokensCount, long providerRemainingCapacity,
                                         long officeRemainingCapacity, long effectiveRemainingCapacity,
                                         boolean providerFull, boolean officeFull) {
        this.providerId = providerId;
        this.providerName = providerName;
        this.username = username;
        this.officeId = officeId;
        this.officeCode = officeCode;
        this.officeDailyMaxTokens = officeDailyMaxTokens;
        this.providerDailyMaxTokens = providerDailyMaxTokens;
        this.providerTodayTokensCount = providerTodayTokensCount;
        this.officeTodayTokensCount = officeTodayTokensCount;
        this.providerRemainingCapacity = providerRemainingCapacity;
        this.officeRemainingCapacity = officeRemainingCapacity;
        this.effectiveRemainingCapacity = effectiveRemainingCapacity;
        this.providerFull = providerFull;
        this.officeFull = officeFull;
    }

    public Long getProviderId() { return providerId; }
    public void setProviderId(Long providerId) { this.providerId = providerId; }

    public String getProviderName() { return providerName; }
    public void setProviderName(String providerName) { this.providerName = providerName; }

    public String getUsername() { return username; }
    public void setUsername(String username) { this.username = username; }

    public Long getOfficeId() { return officeId; }
    public void setOfficeId(Long officeId) { this.officeId = officeId; }

    public String getOfficeCode() { return officeCode; }
    public void setOfficeCode(String officeCode) { this.officeCode = officeCode; }

    public Integer getOfficeDailyMaxTokens() { return officeDailyMaxTokens; }
    public void setOfficeDailyMaxTokens(Integer officeDailyMaxTokens) { this.officeDailyMaxTokens = officeDailyMaxTokens; }

    public Integer getProviderDailyMaxTokens() { return providerDailyMaxTokens; }
    public void setProviderDailyMaxTokens(Integer providerDailyMaxTokens) { this.providerDailyMaxTokens = providerDailyMaxTokens; }

    public long getProviderTodayTokensCount() { return providerTodayTokensCount; }
    public void setProviderTodayTokensCount(long providerTodayTokensCount) { this.providerTodayTokensCount = providerTodayTokensCount; }

    public long getOfficeTodayTokensCount() { return officeTodayTokensCount; }
    public void setOfficeTodayTokensCount(long officeTodayTokensCount) { this.officeTodayTokensCount = officeTodayTokensCount; }

    public long getProviderRemainingCapacity() { return providerRemainingCapacity; }
    public void setProviderRemainingCapacity(long providerRemainingCapacity) { this.providerRemainingCapacity = providerRemainingCapacity; }

    public long getOfficeRemainingCapacity() { return officeRemainingCapacity; }
    public void setOfficeRemainingCapacity(long officeRemainingCapacity) { this.officeRemainingCapacity = officeRemainingCapacity; }

    public long getEffectiveRemainingCapacity() { return effectiveRemainingCapacity; }
    public void setEffectiveRemainingCapacity(long effectiveRemainingCapacity) { this.effectiveRemainingCapacity = effectiveRemainingCapacity; }

    public boolean isProviderFull() { return providerFull; }
    public void setProviderFull(boolean providerFull) { this.providerFull = providerFull; }

    public boolean isOfficeFull() { return officeFull; }
    public void setOfficeFull(boolean officeFull) { this.officeFull = officeFull; }

    public Integer getOfficeDailyMax() { return officeDailyMaxTokens; }
    public Integer getProviderDailyMax() { return providerDailyMaxTokens; }
    public long getProviderTodayTokens() { return providerTodayTokensCount; }
    public long getOfficeTodayTokens() { return officeTodayTokensCount; }
    public long getProviderRemaining() { return providerRemainingCapacity; }
    public long getOfficeRemaining() { return officeRemainingCapacity; }
    public long getEffectiveRemaining() { return effectiveRemainingCapacity; }
}
