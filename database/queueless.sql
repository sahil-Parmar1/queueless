-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Host: 127.0.0.1
-- Generation Time: Oct 06, 2026 at 03:03 PM
-- Server version: 10.4.32-MariaDB
-- PHP Version: 8.2.12

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `queueless`
--

-- --------------------------------------------------------

--
-- Table structure for table `office_documents`
--

CREATE TABLE `office_documents` (
  `id` bigint(20) NOT NULL,
  `content_type` varchar(255) DEFAULT NULL,
  `document_type` varchar(255) NOT NULL,
  `file_size` bigint(20) DEFAULT NULL,
  `file_url` varchar(255) NOT NULL,
  `original_file_name` varchar(255) NOT NULL,
  `uploaded_at` datetime(6) DEFAULT NULL,
  `office_profile_id` bigint(20) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `office_documents`
--

INSERT INTO `office_documents` (`id`, `content_type`, `document_type`, `file_size`, `file_url`, `original_file_name`, `uploaded_at`, `office_profile_id`) VALUES
(1, 'application/octet-stream', 'TRADE_LICENSE', 32317, '/uploads/documents/8021a052-a6b2-4a8c-ad7e-4f04f2adc1cc.pdf', 'Diploma_Professional_Beauty_LookWell_Academy.pdf', '2026-09-29 17:37:19.000000', 1),
(2, 'application/octet-stream', 'OWNER_ID_PROOF', 32317, '/uploads/documents/6b630829-9454-4c8c-a683-fe1a8cc1ec54.pdf', 'Diploma_Professional_Beauty_LookWell_Academy.pdf', '2026-09-29 17:37:20.000000', 1),
(3, 'application/octet-stream', 'CLINIC_REGISTRATION', 189105, '/uploads/documents/2361f6e0-4773-441b-9775-a5c8e9b2b2d1.jpg', 'IMG-20260930-WA0000.jpg', '2026-10-03 18:58:08.000000', 2),
(4, 'application/octet-stream', 'DOCTOR_DEGREE', 78118, '/uploads/documents/133e5293-7424-451b-87f7-a54c2fa1b0b5.jpg', 'IMG-20261001-WA0000.jpg', '2026-10-03 18:58:08.000000', 2);

-- --------------------------------------------------------

--
-- Table structure for table `office_profiles`
--

CREATE TABLE `office_profiles` (
  `id` bigint(20) NOT NULL,
  `address` varchar(255) DEFAULT NULL,
  `category` enum('BANK','CLINIC','OTHER','RESTAURANT','SALON') NOT NULL,
  `city` varchar(255) DEFAULT NULL,
  `closing_time` varchar(255) DEFAULT NULL,
  `created_at` datetime(6) DEFAULT NULL,
  `description` varchar(255) DEFAULT NULL,
  `doctor_name` varchar(255) DEFAULT NULL,
  `medical_registration_number` varchar(255) DEFAULT NULL,
  `office_id` varchar(255) DEFAULT NULL,
  `opening_time` varchar(255) DEFAULT NULL,
  `phone` varchar(255) DEFAULT NULL,
  `pincode` varchar(255) DEFAULT NULL,
  `salon_type` varchar(255) DEFAULT NULL,
  `specialization` varchar(255) DEFAULT NULL,
  `state` varchar(255) DEFAULT NULL,
  `trade_license_number` varchar(255) DEFAULT NULL,
  `verification_status` enum('APPROVED','PENDING','REJECTED') NOT NULL,
  `user_id` bigint(20) NOT NULL,
  `daily_max_tokens` int(11) NOT NULL DEFAULT 60,
  `is_open` bit(1) DEFAULT NULL,
  `latitude` double DEFAULT NULL,
  `longitude` double DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `office_profiles`
--

INSERT INTO `office_profiles` (`id`, `address`, `category`, `city`, `closing_time`, `created_at`, `description`, `doctor_name`, `medical_registration_number`, `office_id`, `opening_time`, `phone`, `pincode`, `salon_type`, `specialization`, `state`, `trade_license_number`, `verification_status`, `user_id`, `daily_max_tokens`, `is_open`, `latitude`, `longitude`) VALUES
(1, 'd234234', 'SALON', '23423dd', '08:00 PM', '2026-09-29 17:37:19.000000', '', NULL, NULL, NULL, '09:00 AM', 'asdfsdfwe', '324234', 'Unisex', NULL, '', '32432fs43', 'APPROVED', 1, 20, b'1', 23.01124405943364, 72.58260439063311),
(2, 'jamalpur jethalal ni chali', 'CLINIC', 'jamalpur', '08:00 PM', '2026-10-03 18:58:07.000000', '', 'dala clinic', 'Med 2638', NULL, '09:00 AM', '1234567890', '380001', NULL, 'general', '', NULL, 'APPROVED', 4, 60, b'1', 23.004624004132744, 72.57972462896414);

-- --------------------------------------------------------

--
-- Table structure for table `providers`
--

CREATE TABLE `providers` (
  `id` bigint(20) NOT NULL,
  `active` bit(1) NOT NULL,
  `contact_number` varchar(255) DEFAULT NULL,
  `created_at` datetime(6) DEFAULT NULL,
  `designation` varchar(255) DEFAULT NULL,
  `email` varchar(255) DEFAULT NULL,
  `name` varchar(255) NOT NULL,
  `password` varchar(255) DEFAULT NULL,
  `updated_at` datetime(6) DEFAULT NULL,
  `username` varchar(100) DEFAULT NULL,
  `office_profile_id` bigint(20) NOT NULL,
  `daily_max_tokens` int(11) DEFAULT NULL,
  `on_duty` bit(1) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `providers`
--

INSERT INTO `providers` (`id`, `active`, `contact_number`, `created_at`, `designation`, `email`, `name`, `password`, `updated_at`, `username`, `office_profile_id`, `daily_max_tokens`, `on_duty`) VALUES
(2, b'1', '98716264165', '2026-09-30 17:25:26.000000', 'asdf', 'sadfsdf@gmail.com', 'hello world', '$2a$10$sL9JNeOSmvcN2jBto6B.GuHV7V0gGYlj41J1K3CVhsg2qPw7PzwAS', '2026-10-03 17:19:39.000000', 'xxxx', 1, 4, b'1'),
(3, b'1', '78459131310', '2026-10-03 17:13:56.000000', 'bread specialist', 'sahil@gmail.com', 'aplesh limabachiya', '$2a$10$ltEeLrR1cuTeslpdPac7te/JoTR2syjWWpO04P/ozsEEqC5BMGlbO', '2026-10-03 17:19:42.000000', 'aaaa', 1, 4, b'1');

-- --------------------------------------------------------

--
-- Table structure for table `provider_schedules`
--

CREATE TABLE `provider_schedules` (
  `id` bigint(20) NOT NULL,
  `day_of_week` enum('FRIDAY','MONDAY','SATURDAY','SUNDAY','THURSDAY','TUESDAY','WEDNESDAY') NOT NULL,
  `end_time` time NOT NULL,
  `start_time` time NOT NULL,
  `provider_id` bigint(20) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `provider_schedules`
--

INSERT INTO `provider_schedules` (`id`, `day_of_week`, `end_time`, `start_time`, `provider_id`) VALUES
(6, 'MONDAY', '23:59:00', '09:00:00', 2),
(7, 'TUESDAY', '23:59:00', '09:00:00', 2),
(18, 'WEDNESDAY', '23:59:00', '09:00:00', 2),
(19, 'THURSDAY', '23:59:00', '09:00:00', 2),
(20, 'FRIDAY', '23:59:00', '06:00:00', 2),
(21, 'SATURDAY', '21:00:00', '09:00:00', 2),
(22, 'SUNDAY', '21:00:00', '09:00:00', 2),
(23, 'MONDAY', '17:00:00', '09:00:00', 3),
(24, 'TUESDAY', '17:00:00', '09:00:00', 3),
(25, 'WEDNESDAY', '17:00:00', '09:00:00', 3),
(26, 'THURSDAY', '17:00:00', '09:00:00', 3),
(27, 'FRIDAY', '17:00:00', '09:00:00', 3),
(28, 'SATURDAY', '21:00:00', '09:00:00', 3),
(29, 'SUNDAY', '21:00:00', '09:00:00', 3);

-- --------------------------------------------------------

--
-- Table structure for table `queue_tokens`
--

CREATE TABLE `queue_tokens` (
  `id` bigint(20) NOT NULL,
  `booked_at` datetime(6) DEFAULT NULL,
  `called_at` datetime(6) DEFAULT NULL,
  `completed_at` datetime(6) DEFAULT NULL,
  `customer_email` varchar(255) DEFAULT NULL,
  `customer_id` bigint(20) DEFAULT NULL,
  `customer_name` varchar(255) NOT NULL,
  `customer_phone` varchar(255) DEFAULT NULL,
  `estimated_wait_minutes` int(11) DEFAULT NULL,
  `sequence_number` int(11) NOT NULL,
  `status` enum('CALLED','CANCELLED','COMPLETED','IN_SERVICE','SKIPPED','WAITING') NOT NULL,
  `token_number` varchar(255) NOT NULL,
  `office_id` bigint(20) NOT NULL,
  `provider_id` bigint(20) DEFAULT NULL,
  `request_status` varchar(255) DEFAULT NULL,
  `requested_provider_id` bigint(20) DEFAULT NULL,
  `service_duration_minutes` int(11) DEFAULT NULL,
  `service_duration_seconds` bigint(20) DEFAULT NULL,
  `serving_started_at` datetime(6) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `queue_tokens`
--

INSERT INTO `queue_tokens` (`id`, `booked_at`, `called_at`, `completed_at`, `customer_email`, `customer_id`, `customer_name`, `customer_phone`, `estimated_wait_minutes`, `sequence_number`, `status`, `token_number`, `office_id`, `provider_id`, `request_status`, `requested_provider_id`, `service_duration_minutes`, `service_duration_seconds`, `serving_started_at`) VALUES
(7, '2026-09-30 18:34:20.000000', NULL, '2026-09-30 18:37:32.000000', 'sahilforread@gmail.com', 2, 'Sahil', NULL, 0, 1, 'COMPLETED', 'S-001', 1, 2, NULL, NULL, NULL, NULL, NULL),
(8, '2026-09-30 18:49:42.000000', NULL, '2026-09-30 18:50:15.000000', 'sahilforread@gmail.com', 2, 'Sahil', NULL, 0, 2, 'COMPLETED', 'S-002', 1, 2, NULL, NULL, NULL, NULL, NULL),
(9, '2026-09-30 18:50:28.000000', NULL, '2026-09-30 18:57:04.000000', 'sahilforread@gmail.com', 2, 'Sahil', NULL, 0, 3, 'COMPLETED', 'S-003', 1, 2, NULL, NULL, NULL, NULL, NULL),
(10, '2026-09-30 18:57:41.000000', NULL, '2026-09-30 18:58:17.000000', 'sahilforread@gmail.com', 2, 'Sahil', NULL, 0, 4, 'COMPLETED', 'S-004', 1, 2, NULL, NULL, NULL, NULL, NULL),
(11, '2026-09-30 18:58:50.000000', '2026-09-30 18:58:56.000000', '2026-09-30 18:59:20.000000', 'sahilforread@gmail.com', 2, 'Sahil', NULL, 0, 5, 'COMPLETED', 'S-005', 1, 2, NULL, NULL, NULL, NULL, NULL),
(12, '2026-09-30 19:01:16.000000', '2026-09-30 19:03:03.000000', '2026-09-30 19:09:34.000000', 'sahilforread@gmail.com', 2, 'Sahil', NULL, 0, 6, 'COMPLETED', 'S-006', 1, 2, NULL, NULL, NULL, NULL, NULL),
(13, '2026-09-30 19:10:24.000000', NULL, '2026-09-30 19:10:56.000000', 'sahilforread@gmail.com', 2, 'Sahil', NULL, 0, 7, 'COMPLETED', 'S-007', 1, 2, NULL, NULL, NULL, NULL, NULL),
(14, '2026-09-30 19:11:19.000000', NULL, '2026-10-01 07:29:25.000000', 'sahilforread@gmail.com', 2, 'Sahil', NULL, 0, 8, 'COMPLETED', 'S-008', 1, 2, NULL, NULL, NULL, NULL, NULL),
(16, '2026-10-01 16:06:38.000000', NULL, '2026-10-01 16:07:13.000000', 'sahilforread@gmail.com', 2, 'Sahil', NULL, 0, 1, 'COMPLETED', 'S-001', 1, 2, NULL, NULL, NULL, NULL, NULL),
(18, '2026-10-01 16:10:18.000000', '2026-10-01 16:10:23.000000', '2026-10-01 16:11:04.000000', 'sahilforread@gmail.com', 2, 'Sahil', NULL, 0, 2, 'COMPLETED', 'S-002', 1, 2, NULL, NULL, NULL, NULL, NULL),
(19, '2026-10-01 16:16:11.000000', '2026-10-01 16:16:22.000000', '2026-10-01 16:16:40.000000', 'sahilforread@gmail.com', 2, 'Sahil', NULL, 0, 3, 'COMPLETED', 'S-003', 1, NULL, NULL, NULL, NULL, NULL, NULL),
(21, '2026-10-01 16:43:27.000000', NULL, '2026-10-01 16:45:11.000000', 'sahilforread@gmail.com', 2, 'Sahil', NULL, 0, 4, 'COMPLETED', 'S-004', 1, 2, NULL, NULL, NULL, NULL, NULL),
(22, '2026-10-01 16:45:26.000000', NULL, NULL, 'sahilforread@gmail.com', 2, 'Sahil', NULL, 0, 5, 'CANCELLED', 'S-005', 1, NULL, NULL, NULL, NULL, NULL, NULL),
(23, '2026-10-01 17:37:31.000000', NULL, '2026-10-01 17:38:58.000000', 'sahilforread@gmail.com', 2, 'Sahil', NULL, 0, 6, 'COMPLETED', 'S-006', 1, 2, NULL, NULL, NULL, NULL, NULL),
(24, '2026-10-01 17:39:18.000000', '2026-10-01 17:39:37.000000', '2026-10-01 17:39:50.000000', 'sahilforread@gmail.com', 2, 'Sahil', NULL, 0, 7, 'COMPLETED', 'S-007', 1, NULL, NULL, NULL, NULL, NULL, NULL),
(25, '2026-10-01 17:45:21.000000', NULL, NULL, 'sahilforread@gmail.com', 2, 'Sahil', NULL, 0, 8, 'CANCELLED', 'S-008', 1, 2, NULL, NULL, NULL, NULL, NULL),
(26, '2026-10-01 21:30:40.000000', NULL, '2026-10-02 08:34:10.000000', 'sahilforread@gmail.com', 2, 'Sahil', NULL, 0, 9, 'COMPLETED', 'S-009', 1, 2, NULL, NULL, NULL, NULL, NULL),
(27, '2026-10-02 09:50:45.000000', NULL, NULL, 'sahilforread@gmail.com', 2, 'Sahil', NULL, 0, 1, 'SKIPPED', 'S-001', 1, 2, NULL, NULL, NULL, NULL, NULL),
(28, '2026-10-02 09:52:44.000000', NULL, '2026-10-02 12:31:02.000000', 'sahilforread@gmail.com', 2, 'Sahil', NULL, 0, 2, 'COMPLETED', 'S-002', 1, 2, NULL, NULL, NULL, NULL, NULL),
(29, '2026-10-02 12:31:33.000000', NULL, '2026-10-02 12:33:30.000000', 'sahilforread@gmail.com', 2, 'Sahil', NULL, 0, 3, 'COMPLETED', 'S-003', 1, 2, NULL, NULL, NULL, NULL, NULL),
(30, '2026-10-02 12:33:45.000000', NULL, '2026-10-02 12:40:57.000000', 'sahilforread@gmail.com', 2, 'Sahil', NULL, 0, 4, 'COMPLETED', 'S-004', 1, 2, NULL, NULL, NULL, NULL, NULL),
(31, '2026-10-02 12:41:39.000000', '2026-10-02 12:43:57.000000', '2026-10-02 12:45:53.000000', 'sahilforread@gmail.com', 2, 'Sahil', NULL, 0, 5, 'COMPLETED', 'S-005', 1, NULL, NULL, NULL, NULL, NULL, NULL),
(32, '2026-10-02 12:46:22.000000', NULL, '2026-10-02 13:10:16.000000', 'sahilforread@gmail.com', 2, 'Sahil', NULL, 0, 6, 'COMPLETED', 'S-006', 1, 2, NULL, NULL, NULL, NULL, NULL),
(33, '2026-10-02 13:10:48.000000', NULL, '2026-10-02 13:12:56.000000', 'sahilforread@gmail.com', 2, 'Sahil', NULL, 0, 7, 'COMPLETED', 'S-007', 1, 2, NULL, NULL, NULL, NULL, NULL),
(34, '2026-10-02 13:21:11.000000', NULL, '2026-10-02 13:21:57.000000', 'sahilforread@gmail.com', 2, 'Sahil', NULL, 0, 8, 'COMPLETED', 'S-008', 1, 2, NULL, NULL, NULL, NULL, NULL),
(35, '2026-10-02 13:23:58.000000', NULL, '2026-10-02 13:48:17.000000', 'sahilforread@gmail.com', 2, 'Sahil', NULL, 0, 9, 'COMPLETED', 'S-009', 1, 2, NULL, NULL, NULL, NULL, NULL),
(36, '2026-10-02 13:48:33.000000', '2026-10-02 13:48:50.000000', '2026-10-02 13:48:54.000000', 'sahilforread@gmail.com', 2, 'Sahil', NULL, 0, 10, 'COMPLETED', 'S-010', 1, NULL, 'REJECTED', NULL, NULL, NULL, NULL),
(37, '2026-10-02 14:08:57.000000', NULL, '2026-10-02 14:09:07.000000', 'sahilforread@gmail.com', 2, 'Sahil', NULL, 0, 11, 'COMPLETED', 'S-011', 1, 2, NULL, NULL, NULL, NULL, NULL),
(38, '2026-10-02 18:25:01.000000', NULL, '2026-10-02 18:26:15.000000', 'sahilforread@gmail.com', 2, 'Sahil', NULL, 0, 12, 'COMPLETED', 'S-012', 1, 2, NULL, NULL, NULL, NULL, NULL),
(39, '2026-10-02 18:25:25.000000', NULL, '2026-10-02 18:26:42.000000', 'sahilforxyz@gmail.com', 3, 'Sahil Kumar', NULL, 12, 13, 'COMPLETED', 'S-013', 1, 2, NULL, NULL, NULL, NULL, NULL),
(40, '2026-10-02 18:26:54.000000', NULL, '2026-10-02 18:27:30.000000', 'sahilforread@gmail.com', 2, 'Sahil', NULL, 0, 14, 'COMPLETED', 'S-014', 1, 2, NULL, NULL, NULL, NULL, NULL),
(41, '2026-10-02 18:27:06.000000', NULL, '2026-10-02 18:28:06.000000', 'sahilforxyz@gmail.com', 3, 'Sahil Kumar', NULL, 12, 15, 'COMPLETED', 'S-015', 1, 2, NULL, NULL, NULL, NULL, NULL),
(42, '2026-10-02 18:28:48.000000', '2026-10-02 18:28:51.000000', '2026-10-02 18:29:08.000000', 'sahilforxyz@gmail.com', 3, 'Sahil Kumar', NULL, 0, 16, 'COMPLETED', 'S-016', 1, 2, NULL, NULL, NULL, NULL, NULL),
(43, '2026-10-02 19:05:31.000000', NULL, '2026-10-02 19:05:40.000000', 'sahilforxyz@gmail.com', 3, 'Sahil Kumar', NULL, 0, 17, 'COMPLETED', 'S-017', 1, 2, NULL, NULL, NULL, NULL, NULL),
(44, '2026-10-02 19:08:55.000000', NULL, '2026-10-02 19:09:15.000000', 'sahilforxyz@gmail.com', 3, 'Sahil Kumar', NULL, 0, 18, 'COMPLETED', 'S-018', 1, 2, NULL, NULL, NULL, NULL, NULL),
(45, '2026-10-02 19:14:39.000000', NULL, '2026-10-02 19:14:46.000000', 'sahilforxyz@gmail.com', 3, 'Sahil Kumar', NULL, 0, 19, 'COMPLETED', 'S-019', 1, 2, NULL, NULL, NULL, NULL, NULL),
(46, '2026-10-02 19:20:21.000000', NULL, '2026-10-02 19:20:33.000000', 'sahilforxyz@gmail.com', 3, 'Sahil Kumar', NULL, 0, 20, 'COMPLETED', 'S-020', 1, 2, NULL, NULL, NULL, NULL, NULL),
(47, '2026-10-02 19:20:47.000000', NULL, '2026-10-02 19:21:17.000000', 'sahilforxyz@gmail.com', 3, 'Sahil Kumar', NULL, 0, 21, 'COMPLETED', 'S-021', 1, 2, NULL, NULL, NULL, NULL, NULL),
(48, '2026-10-03 17:10:11.000000', NULL, '2026-10-03 17:10:45.000000', 'sahilforread@gmail.com', 2, 'Sahil', NULL, 0, 1, 'COMPLETED', 'S-001', 1, 2, NULL, NULL, NULL, NULL, NULL),
(49, '2026-10-03 17:10:59.000000', NULL, '2026-10-03 17:11:42.000000', 'sahilforread@gmail.com', 2, 'Sahil', NULL, 0, 2, 'COMPLETED', 'S-002', 1, 2, NULL, NULL, NULL, NULL, NULL),
(50, '2026-10-03 17:17:05.000000', NULL, '2026-10-03 17:17:17.000000', 'sahilforread@gmail.com', 2, 'Sahil', NULL, 0, 3, 'COMPLETED', 'S-003', 1, 3, NULL, NULL, NULL, NULL, NULL),
(51, '2026-10-03 17:18:04.000000', NULL, '2026-10-03 17:18:28.000000', 'sahilforread@gmail.com', 2, 'Sahil', NULL, 0, 4, 'COMPLETED', 'S-004', 1, 2, NULL, NULL, NULL, NULL, NULL),
(52, '2026-10-03 17:28:17.000000', NULL, '2026-10-03 17:28:29.000000', 'sahilforread@gmail.com', 2, 'Sahil', NULL, 0, 5, 'COMPLETED', 'S-005', 1, 2, NULL, NULL, NULL, NULL, NULL),
(53, '2026-10-03 17:36:03.000000', NULL, NULL, 'sahilforxyz@gmail.com', 3, 'Sahil Kumar', NULL, 0, 6, 'SKIPPED', 'S-006', 1, 2, NULL, NULL, NULL, NULL, NULL),
(54, '2026-10-03 17:36:28.000000', NULL, '2026-10-03 17:39:05.000000', 'sahilforread@gmail.com', 2, 'Sahil', NULL, 12, 7, 'COMPLETED', 'S-007', 1, 2, NULL, NULL, NULL, NULL, NULL),
(55, '2026-10-03 17:38:09.000000', '2026-10-03 17:39:05.000000', '2026-10-03 17:39:16.000000', 'sahilforxyz@gmail.com', 3, 'Sahil Kumar', NULL, 12, 8, 'COMPLETED', 'S-008', 1, 2, NULL, NULL, NULL, NULL, NULL),
(56, '2026-10-03 17:40:27.000000', NULL, '2026-10-03 17:41:31.000000', 'sahilforxyz@gmail.com', 3, 'Sahil Kumar', NULL, 0, 9, 'COMPLETED', 'S-009', 1, 2, NULL, NULL, NULL, NULL, NULL),
(57, '2026-10-03 17:40:37.000000', NULL, '2026-10-03 17:41:40.000000', 'sahilforread@gmail.com', 2, 'Sahil', NULL, 12, 10, 'COMPLETED', 'S-010', 1, 2, NULL, NULL, NULL, NULL, NULL),
(58, '2026-10-03 17:42:08.000000', '2026-10-03 17:42:47.000000', '2026-10-03 17:45:27.000000', 'sahilforxyz@gmail.com', 3, 'Sahil Kumar', NULL, 0, 11, 'COMPLETED', 'S-011', 1, 2, NULL, NULL, NULL, NULL, NULL),
(59, '2026-10-03 17:42:15.000000', NULL, '2026-10-03 18:03:07.000000', 'sahilforread@gmail.com', 2, 'Sahil', NULL, 12, 13, 'COMPLETED', 'S-012', 1, 2, NULL, NULL, NULL, NULL, NULL),
(60, '2026-10-03 18:02:30.000000', '2026-10-03 18:02:47.000000', '2026-10-03 18:02:58.000000', 'sahilforxyz@gmail.com', 3, 'Sahil Kumar', NULL, 12, 12, 'COMPLETED', 'S-013', 1, 2, NULL, NULL, NULL, NULL, NULL),
(61, '2026-10-03 19:20:25.000000', NULL, '2026-10-03 19:20:51.000000', 'sahilforxyz@gmail.com', 3, 'Sahil Kumar', NULL, 0, 14, 'COMPLETED', 'S-014', 1, 2, NULL, NULL, NULL, NULL, NULL),
(62, '2026-10-03 19:33:01.000000', NULL, '2026-10-03 19:33:29.000000', 'sahilforxyz@gmail.com', 3, 'Sahil Kumar', NULL, 0, 15, 'COMPLETED', 'S-015', 1, 2, NULL, NULL, NULL, NULL, NULL),
(63, '2026-10-03 19:38:21.000000', NULL, NULL, 'sahilforxyz@gmail.com', 3, 'Sahil Kumar', NULL, 0, 1, 'CANCELLED', 'C-001', 2, NULL, NULL, NULL, NULL, NULL, NULL),
(64, '2026-10-03 19:38:57.000000', NULL, '2026-10-03 19:39:17.000000', 'sahilforxyz@gmail.com', 3, 'Sahil Kumar', NULL, 0, 16, 'COMPLETED', 'S-016', 1, 2, NULL, NULL, NULL, NULL, NULL),
(65, '2026-10-03 19:40:00.000000', NULL, '2026-10-03 19:40:13.000000', 'sahilforxyz@gmail.com', 3, 'Sahil Kumar', NULL, 0, 17, 'COMPLETED', 'S-017', 1, 2, NULL, NULL, NULL, NULL, NULL),
(66, '2026-10-03 21:05:36.000000', '2026-10-03 21:05:41.000000', '2026-10-03 21:05:56.000000', 'sahilforread@gmail.com', 2, 'Sahil', NULL, 0, 18, 'COMPLETED', 'S-018', 1, NULL, NULL, NULL, NULL, NULL, NULL),
(67, '2026-10-06 18:27:49.000000', NULL, '2026-10-06 18:28:47.000000', 'sahilforread@gmail.com', 2, 'Sahil', NULL, 0, 1, 'COMPLETED', 'S-001', 1, 2, NULL, NULL, 1, 53, '2026-10-06 18:27:54.000000');

-- --------------------------------------------------------

--
-- Table structure for table `users`
--

CREATE TABLE `users` (
  `id` bigint(20) NOT NULL,
  `created_at` datetime(6) DEFAULT NULL,
  `email` varchar(255) NOT NULL,
  `enabled` bit(1) NOT NULL,
  `google_id` varchar(255) DEFAULT NULL,
  `name` varchar(255) NOT NULL,
  `office_id` varchar(255) DEFAULT NULL,
  `password` varchar(255) DEFAULT NULL,
  `role` enum('CUSTOMER','OFFICE') NOT NULL,
  `updated_at` datetime(6) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `users`
--

INSERT INTO `users` (`id`, `created_at`, `email`, `enabled`, `google_id`, `name`, `office_id`, `password`, `role`, `updated_at`) VALUES
(1, '2026-09-29 17:36:56.000000', 'sahilforsave@gmail.com', b'1', 'RK5VpxgOWLbXaSQ3Jpzzzw9JJmf1', 'sahil parmar', 'OFF-2HJQP3', NULL, 'OFFICE', '2026-09-29 17:36:56.000000'),
(2, '2026-09-29 18:48:01.000000', 'sahilforread@gmail.com', b'1', 'saHpsk38tSbGdksrZ4Vn1A0NjTP2', 'Sahil', NULL, NULL, 'CUSTOMER', '2026-09-29 18:48:01.000000'),
(3, '2026-10-02 18:24:18.000000', 'sahilforxyz@gmail.com', b'1', 'j4DaLCcwtIhRODBLdbrgY4oGltu2', 'Sahil Kumar', NULL, NULL, 'CUSTOMER', '2026-10-02 18:24:18.000000'),
(4, '2026-10-03 18:38:13.000000', 'sp9925438084@gmail.com', b'1', 'pTfMZIdrefO5kic7PLAih9UieM93', 'sahil parmar', 'OFF-4BF5QT', NULL, 'OFFICE', '2026-10-03 18:38:13.000000');

--
-- Indexes for dumped tables
--

--
-- Indexes for table `office_documents`
--
ALTER TABLE `office_documents`
  ADD PRIMARY KEY (`id`),
  ADD KEY `FKr58ruviblo680ni7gpxwipp9w` (`office_profile_id`);

--
-- Indexes for table `office_profiles`
--
ALTER TABLE `office_profiles`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `UK13q3sokmi4ltap40o06ihsau` (`user_id`),
  ADD UNIQUE KEY `UKsd43yc096srpn6aifjb0rfxe6` (`office_id`);

--
-- Indexes for table `providers`
--
ALTER TABLE `providers`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `uk_office_provider_username` (`office_profile_id`,`username`);

--
-- Indexes for table `provider_schedules`
--
ALTER TABLE `provider_schedules`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `UK8tp8w4d9knv768o0br9d7fbf2` (`provider_id`,`day_of_week`);

--
-- Indexes for table `queue_tokens`
--
ALTER TABLE `queue_tokens`
  ADD PRIMARY KEY (`id`),
  ADD KEY `FK7ayn34u1le2e90esijp8458d` (`office_id`),
  ADD KEY `FKnf1vq4o4iarcyv634x7hvq2iv` (`provider_id`),
  ADD KEY `FKqmx5oe6b4d8t6fh4q74dlpsk` (`requested_provider_id`);

--
-- Indexes for table `users`
--
ALTER TABLE `users`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `UK6dotkott2kjsp8vw4d0m25fb7` (`email`),
  ADD UNIQUE KEY `UKovh8xmu9ac27t18m56gri58i1` (`google_id`),
  ADD UNIQUE KEY `UK56uaxpupwbxs58tx3uau7jny1` (`office_id`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `office_documents`
--
ALTER TABLE `office_documents`
  MODIFY `id` bigint(20) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=5;

--
-- AUTO_INCREMENT for table `office_profiles`
--
ALTER TABLE `office_profiles`
  MODIFY `id` bigint(20) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- AUTO_INCREMENT for table `providers`
--
ALTER TABLE `providers`
  MODIFY `id` bigint(20) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

--
-- AUTO_INCREMENT for table `provider_schedules`
--
ALTER TABLE `provider_schedules`
  MODIFY `id` bigint(20) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=30;

--
-- AUTO_INCREMENT for table `queue_tokens`
--
ALTER TABLE `queue_tokens`
  MODIFY `id` bigint(20) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=68;

--
-- AUTO_INCREMENT for table `users`
--
ALTER TABLE `users`
  MODIFY `id` bigint(20) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=5;

--
-- Constraints for dumped tables
--

--
-- Constraints for table `office_documents`
--
ALTER TABLE `office_documents`
  ADD CONSTRAINT `FKr58ruviblo680ni7gpxwipp9w` FOREIGN KEY (`office_profile_id`) REFERENCES `office_profiles` (`id`);

--
-- Constraints for table `office_profiles`
--
ALTER TABLE `office_profiles`
  ADD CONSTRAINT `FKimvn7onqrtpdrrqekqfk2h3wp` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`);

--
-- Constraints for table `providers`
--
ALTER TABLE `providers`
  ADD CONSTRAINT `FKmi4he5vmjba5205cvc7mg369p` FOREIGN KEY (`office_profile_id`) REFERENCES `office_profiles` (`id`);

--
-- Constraints for table `provider_schedules`
--
ALTER TABLE `provider_schedules`
  ADD CONSTRAINT `FKt7l5c78iuumnmhplxvg67lrmq` FOREIGN KEY (`provider_id`) REFERENCES `providers` (`id`);

--
-- Constraints for table `queue_tokens`
--
ALTER TABLE `queue_tokens`
  ADD CONSTRAINT `FK7ayn34u1le2e90esijp8458d` FOREIGN KEY (`office_id`) REFERENCES `office_profiles` (`id`),
  ADD CONSTRAINT `FKnf1vq4o4iarcyv634x7hvq2iv` FOREIGN KEY (`provider_id`) REFERENCES `providers` (`id`),
  ADD CONSTRAINT `FKqmx5oe6b4d8t6fh4q74dlpsk` FOREIGN KEY (`requested_provider_id`) REFERENCES `providers` (`id`);
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
