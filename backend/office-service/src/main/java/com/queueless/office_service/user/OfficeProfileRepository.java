package com.queueless.office_service.user;

import java.util.List;
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

@Repository
public interface OfficeProfileRepository extends JpaRepository<OfficeProfile, Long> {

    Optional<OfficeProfile> findByUserId(Long userId);

    Optional<OfficeProfile> findByUserEmail(String email);

    List<OfficeProfile> findByVerificationStatus(VerificationStatus status);

    List<OfficeProfile> findByCategory(OfficeCategory category);

    @Query("SELECT p FROM OfficeProfile p WHERE " +
           "(:status IS NULL OR p.verificationStatus = :status) AND " +
           "(:category IS NULL OR p.category = :category) AND " +
           "(:city IS NULL OR LOWER(p.city) LIKE LOWER(CONCAT('%', :city, '%'))) AND " +
           "(:query IS NULL OR :query = '' OR (" +
           "  LOWER(p.user.name) LIKE LOWER(CONCAT('%', :query, '%')) OR " +
           "  LOWER(COALESCE(p.doctorName, '')) LIKE LOWER(CONCAT('%', :query, '%')) OR " +
           "  LOWER(COALESCE(p.specialization, '')) LIKE LOWER(CONCAT('%', :query, '%')) OR " +
           "  LOWER(COALESCE(p.salonType, '')) LIKE LOWER(CONCAT('%', :query, '%')) OR " +
           "  LOWER(COALESCE(p.city, '')) LIKE LOWER(CONCAT('%', :query, '%')) OR " +
           "  LOWER(COALESCE(p.address, '')) LIKE LOWER(CONCAT('%', :query, '%')) OR " +
           "  LOWER(COALESCE(p.description, '')) LIKE LOWER(CONCAT('%', :query, '%'))" +
           "))")
    List<OfficeProfile> searchOffices(
            @Param("query") String query,
            @Param("category") OfficeCategory category,
            @Param("city") String city,
            @Param("status") VerificationStatus status
    );
}
