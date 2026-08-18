package com.queueless.office_service.user;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

import jakarta.persistence.CascadeType;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.OneToMany;
import jakarta.persistence.OneToOne;
import jakarta.persistence.Table;

@Entity
@Table(name = "office_profiles")
public class OfficeProfile {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @OneToOne
    @JoinColumn(name = "user_id", nullable = false, unique = true)
    private User user;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private OfficeCategory category;

    private String phone;
    private String address;
    private String city;
    private String state;
    private String pincode;
    private String openingTime;
    private String closingTime;
    private String description;

    // --- Clinic Specific Details ---
    private String doctorName;
    private String specialization;
    private String medicalRegistrationNumber;

    // --- Salon Specific Details ---
    private String salonType; // Unisex, Male, Female
    private String tradeLicenseNumber;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private VerificationStatus verificationStatus = VerificationStatus.PENDING;

    @OneToMany(mappedBy = "officeProfile", cascade = CascadeType.ALL, orphanRemoval = true)
    private List<OfficeDocument> documents = new ArrayList<>();

    @Column(name = "created_at")
    private LocalDateTime createdAt = LocalDateTime.now();

    // Getters and Setters...
    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    public User getUser() { return user; }
    public void setUser(User user) { this.user = user; }
    public OfficeCategory getCategory() { return category; }
    public void setCategory(OfficeCategory category) { this.category = category; }
    public String getPhone() { return phone; }
    public void setPhone(String phone) { this.phone = phone; }
    public String getAddress() { return address; }
    public void setAddress(String address) { this.address = address; }
    public String getCity() { return city; }
    public void setCity(String city) { this.city = city; }
    public String getState() { return state; }
    public void setState(String state) { this.state = state; }
    public String getPincode() { return pincode; }
    public void setPincode(String pincode) { this.pincode = pincode; }
    public String getOpeningTime() { return openingTime; }
    public void setOpeningTime(String openingTime) { this.openingTime = openingTime; }
    public String getClosingTime() { return closingTime; }
    public void setClosingTime(String closingTime) { this.closingTime = closingTime; }
    public String getDescription() { return description; }
    public void setDescription(String description) { this.description = description; }
    public String getDoctorName() { return doctorName; }
    public void setDoctorName(String doctorName) { this.doctorName = doctorName; }
    public String getSpecialization() { return specialization; }
    public void setSpecialization(String specialization) { this.specialization = specialization; }
    public String getMedicalRegistrationNumber() { return medicalRegistrationNumber; }
    public void setMedicalRegistrationNumber(String medicalRegistrationNumber) { this.medicalRegistrationNumber = medicalRegistrationNumber; }
    public String getSalonType() { return salonType; }
    public void setSalonType(String salonType) { this.salonType = salonType; }
    public String getTradeLicenseNumber() { return tradeLicenseNumber; }
    public void setTradeLicenseNumber(String tradeLicenseNumber) { this.tradeLicenseNumber = tradeLicenseNumber; }
    public VerificationStatus getVerificationStatus() { return verificationStatus; }
    public void setVerificationStatus(VerificationStatus verificationStatus) { this.verificationStatus = verificationStatus; }
    public List<OfficeDocument> getDocuments() { return documents; }
    public void setDocuments(List<OfficeDocument> documents) { this.documents = documents; }
    public LocalDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(LocalDateTime createdAt) { this.createdAt = createdAt; }
}
