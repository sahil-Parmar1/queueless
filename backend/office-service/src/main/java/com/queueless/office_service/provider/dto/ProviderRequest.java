package com.queueless.office_service.provider.dto;

import java.util.ArrayList;
import java.util.List;

public class ProviderRequest {

    private String name;
    private String username;
    private String password;
    private String designation;
    private String contactNumber;
    private String email;
    private Boolean active = true;
    private List<ProviderScheduleDto> schedules = new ArrayList<>();

    public String getUsername() {
        return username;
    }

    public void setUsername(String username) {
        this.username = username;
    }

    public String getPassword() {
        return password;
    }

    public void setPassword(String password) {
        this.password = password;
    }

    public String getName() {
        return name;
    }

    public void setName(String name) {
        this.name = name;
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
}
