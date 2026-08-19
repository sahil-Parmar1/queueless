package com.queueless.office_service.user;

import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface OfficeProfileRepository extends JpaRepository<OfficeProfile, Long> {
    Optional<OfficeProfile> findByUserId(Long userId);
    Optional<OfficeProfile> findByUserEmail(String email);
}
