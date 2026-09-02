-- phpMyAdmin SQL Dump
-- Database: `queueless`

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

-- --------------------------------------------------------

--
-- Table structure for table `users`
--

CREATE TABLE IF NOT EXISTS `users` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `email` varchar(255) NOT NULL,
  `name` varchar(255) NOT NULL,
  `password` varchar(255) DEFAULT NULL,
  `google_id` varchar(255) DEFAULT NULL,
  `role` enum('CUSTOMER','OFFICE') NOT NULL,
  `enabled` tinyint(1) NOT NULL DEFAULT 1,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `email` (`email`),
  UNIQUE KEY `google_id` (`google_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `office_profiles`
--

CREATE TABLE IF NOT EXISTS `office_profiles` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `user_id` bigint(20) NOT NULL,
  `category` enum('CLINIC','SALON','BANK','RESTAURANT','OTHER') NOT NULL,
  `phone` varchar(50) DEFAULT NULL,
  `address` varchar(255) DEFAULT NULL,
  `city` varchar(100) DEFAULT NULL,
  `state` varchar(100) DEFAULT NULL,
  `pincode` varchar(20) DEFAULT NULL,
  `opening_time` varchar(50) DEFAULT NULL,
  `closing_time` varchar(50) DEFAULT NULL,
  `description` text DEFAULT NULL,
  `doctor_name` varchar(255) DEFAULT NULL,
  `specialization` varchar(255) DEFAULT NULL,
  `medical_registration_number` varchar(100) DEFAULT NULL,
  `salon_type` varchar(50) DEFAULT NULL,
  `trade_license_number` varchar(100) DEFAULT NULL,
  `verification_status` enum('PENDING','APPROVED','REJECTED') NOT NULL DEFAULT 'PENDING',
  `created_at` datetime(6) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `user_id` (`user_id`),
  CONSTRAINT `fk_office_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `office_documents`
--

CREATE TABLE IF NOT EXISTS `office_documents` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `office_profile_id` bigint(20) NOT NULL,
  `document_type` varchar(100) NOT NULL,
  `original_file_name` varchar(255) NOT NULL,
  `file_url` varchar(500) NOT NULL,
  `content_type` varchar(100) DEFAULT NULL,
  `file_size` bigint(20) DEFAULT NULL,
  `uploaded_at` datetime(6) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `office_profile_id` (`office_profile_id`),
  CONSTRAINT `fk_document_office` FOREIGN KEY (`office_profile_id`) REFERENCES `office_profiles` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `queue_tokens` (NEW IN THIS CHANGE)
--

CREATE TABLE IF NOT EXISTS `queue_tokens` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `token_number` varchar(50) NOT NULL,
  `sequence_number` int(11) NOT NULL,
  `office_id` bigint(20) NOT NULL,
  `customer_id` bigint(20) DEFAULT NULL,
  `customer_name` varchar(255) NOT NULL,
  `customer_phone` varchar(50) DEFAULT NULL,
  `customer_email` varchar(255) DEFAULT NULL,
  `status` enum('WAITING','CALLED','IN_SERVICE','COMPLETED','SKIPPED','CANCELLED') NOT NULL DEFAULT 'WAITING',
  `estimated_wait_minutes` int(11) DEFAULT NULL,
  `booked_at` datetime(6) DEFAULT NULL,
  `called_at` datetime(6) DEFAULT NULL,
  `completed_at` datetime(6) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `office_id` (`office_id`),
  KEY `customer_id` (`customer_id`),
  KEY `idx_office_status` (`office_id`, `status`),
  CONSTRAINT `fk_token_office` FOREIGN KEY (`office_id`) REFERENCES `office_profiles` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
