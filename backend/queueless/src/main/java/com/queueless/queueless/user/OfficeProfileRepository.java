package com.queueless.queueless.user;
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;

public interface OfficeProfileRepository extends JpaRepository<OfficeProfile, Long> {
    Optional<OfficeProfile> findByUserId(Long userId);
    Optional<OfficeProfile> findByUserEmail(String email);
}