package com.queueless.office_service.user.dto;

public class OfficeQueueSettingsResponse {
    private Long officeId;
    private String officeCode;
    private Integer dailyMaxTokens;
    private long todayTokensCount;
    private long remainingCapacity;
    private int allocatedProviderLimits;
    private int unallocatedCapacity;
    private boolean officeFull;

    public OfficeQueueSettingsResponse() {}

    public OfficeQueueSettingsResponse(Long officeId, String officeCode, Integer dailyMaxTokens,
                                       long todayTokensCount, long remainingCapacity,
                                       int allocatedProviderLimits, int unallocatedCapacity,
                                       boolean officeFull) {
        this.officeId = officeId;
        this.officeCode = officeCode;
        this.dailyMaxTokens = dailyMaxTokens;
        this.todayTokensCount = todayTokensCount;
        this.remainingCapacity = remainingCapacity;
        this.allocatedProviderLimits = allocatedProviderLimits;
        this.unallocatedCapacity = unallocatedCapacity;
        this.officeFull = officeFull;
    }

    public Long getOfficeId() { return officeId; }
    public void setOfficeId(Long officeId) { this.officeId = officeId; }

    public String getOfficeCode() { return officeCode; }
    public void setOfficeCode(String officeCode) { this.officeCode = officeCode; }

    public Integer getDailyMaxTokens() { return dailyMaxTokens; }
    public void setDailyMaxTokens(Integer dailyMaxTokens) { this.dailyMaxTokens = dailyMaxTokens; }

    public long getTodayTokensCount() { return todayTokensCount; }
    public void setTodayTokensCount(long todayTokensCount) { this.todayTokensCount = todayTokensCount; }

    public long getRemainingCapacity() { return remainingCapacity; }
    public void setRemainingCapacity(long remainingCapacity) { this.remainingCapacity = remainingCapacity; }

    public int getAllocatedProviderLimits() { return allocatedProviderLimits; }
    public void setAllocatedProviderLimits(int allocatedProviderLimits) { this.allocatedProviderLimits = allocatedProviderLimits; }

    public int getUnallocatedCapacity() { return unallocatedCapacity; }
    public void setUnallocatedCapacity(int unallocatedCapacity) { this.unallocatedCapacity = unallocatedCapacity; }

    public boolean isOfficeFull() { return officeFull; }
    public void setOfficeFull(boolean officeFull) { this.officeFull = officeFull; }

    public long getTodayTokens() { return todayTokensCount; }
    public long getRemaining() { return remainingCapacity; }
    public boolean isFull() { return officeFull; }
}
