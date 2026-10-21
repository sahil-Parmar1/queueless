-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Host: 127.0.0.1
-- Generation Time: Oct 21, 2026 at 02:24 PM
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
-- Table structure for table `customer_favorite_offices`
--

CREATE TABLE `customer_favorite_offices` (
  `id` bigint(20) NOT NULL,
  `created_at` datetime(6) DEFAULT NULL,
  `customer_email` varchar(255) DEFAULT NULL,
  `customer_id` bigint(20) NOT NULL,
  `office_id` bigint(20) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `customer_favorite_offices`
--

INSERT INTO `customer_favorite_offices` (`id`, `created_at`, `customer_email`, `customer_id`, `office_id`) VALUES
(5, '2026-10-20 10:12:39.000000', 'sp9925438084@gmail.com', 4, 1);

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
(4, 'application/octet-stream', 'DOCTOR_DEGREE', 78118, '/uploads/documents/133e5293-7424-451b-87f7-a54c2fa1b0b5.jpg', 'IMG-20261001-WA0000.jpg', '2026-10-03 18:58:08.000000', 2),
(5, 'application/octet-stream', 'CLINIC_REGISTRATION', 9004, '/uploads/documents/59f5a27c-91b1-4a66-87a6-98444917e177.jpg', 'IMG-20261009-WA0005.jpg', '2026-10-11 15:54:53.000000', 3);

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
(1, 'd234234', 'SALON', '23423dd', '08:00 PM', '2026-09-29 17:37:19.000000', '', NULL, NULL, NULL, '09:00 AM', 'asdfsdfwe', '324234', 'Unisex', NULL, '', '32432fs43', 'APPROVED', 1, 100, b'1', 23.01124405943364, 72.58260439063311),
(2, 'jamalpur jethalal ni chali', 'CLINIC', 'jamalpur', '08:00 PM', '2026-10-03 18:58:07.000000', '', 'dala clinic', 'Med 2638', NULL, '09:00 AM', '1234567890', '380001', NULL, 'general', '', NULL, 'APPROVED', 4, 60, b'1', 23.004624004132744, 72.57972462896414),
(3, 'jamalpur char rasta', 'CLINIC', 'jamalpur', '08:00 PM', '2026-10-11 15:54:53.000000', '', 'gujarat vidyapeeth general clinic', 'med28282', NULL, '09:00 AM', '3194348846', '380022', NULL, 'general', '', NULL, 'APPROVED', 5, 60, b'1', 23.014691757684513, 72.57580435745469);

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
(2, b'1', '98716264165', '2026-09-30 17:25:26.000000', 'asdf', 'sadfsdf@gmail.com', 'hello world', '$2a$10$sL9JNeOSmvcN2jBto6B.GuHV7V0gGYlj41J1K3CVhsg2qPw7PzwAS', '2026-10-21 15:46:55.000000', 'xxxx', 1, 50, b'1'),
(3, b'1', '78459131310', '2026-10-03 17:13:56.000000', 'bread specialist', 'sahil@gmail.com', 'aplesh limabachiya', '$2a$10$ltEeLrR1cuTeslpdPac7te/JoTR2syjWWpO04P/ozsEEqC5BMGlbO', '2026-10-03 17:19:42.000000', 'aaaa', 1, 4, b'1'),
(4, b'1', '3194529484', '2026-10-11 16:04:03.000000', 'orthopedic', 'pratik@gmail.com', 'pratik padhiyar', '$2a$10$XK8HrW2rd/XyQdT3OX6oy.SFvtrYQVdi97crScLzatHqz1MEOxViO', '2026-10-11 17:11:28.000000', 'pppp', 3, NULL, b'1');

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
(29, 'SUNDAY', '21:00:00', '09:00:00', 3),
(30, 'MONDAY', '17:00:00', '09:00:00', 4),
(31, 'TUESDAY', '17:00:00', '09:00:00', 4),
(32, 'WEDNESDAY', '17:00:00', '09:00:00', 4),
(33, 'THURSDAY', '17:00:00', '09:00:00', 4),
(34, 'FRIDAY', '17:00:00', '09:00:00', 4),
(35, 'SATURDAY', '17:00:00', '09:00:00', 4),
(36, 'SUNDAY', '17:00:00', '09:00:00', 4);

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
  `serving_started_at` datetime(6) DEFAULT NULL,
  `task_description` varchar(25) DEFAULT NULL,
  `is_priority` bit(1) DEFAULT NULL,
  `priority_reason` varchar(255) DEFAULT NULL,
  `priority_requested_at` datetime(6) DEFAULT NULL,
  `priority_status` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `queue_tokens`
--

INSERT INTO `queue_tokens` (`id`, `booked_at`, `called_at`, `completed_at`, `customer_email`, `customer_id`, `customer_name`, `customer_phone`, `estimated_wait_minutes`, `sequence_number`, `status`, `token_number`, `office_id`, `provider_id`, `request_status`, `requested_provider_id`, `service_duration_minutes`, `service_duration_seconds`, `serving_started_at`, `task_description`, `is_priority`, `priority_reason`, `priority_requested_at`, `priority_status`) VALUES
(7, '2026-09-30 18:34:20.000000', NULL, '2026-09-30 18:37:32.000000', 'sahilforread@gmail.com', 2, 'Sahil', NULL, 0, 1, 'COMPLETED', 'S-001', 1, 2, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
(8, '2026-09-30 18:49:42.000000', NULL, '2026-09-30 18:50:15.000000', 'sahilforread@gmail.com', 2, 'Sahil', NULL, 0, 2, 'COMPLETED', 'S-002', 1, 2, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
(9, '2026-09-30 18:50:28.000000', NULL, '2026-09-30 18:57:04.000000', 'sahilforread@gmail.com', 2, 'Sahil', NULL, 0, 3, 'COMPLETED', 'S-003', 1, 2, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
(10, '2026-09-30 18:57:41.000000', NULL, '2026-09-30 18:58:17.000000', 'sahilforread@gmail.com', 2, 'Sahil', NULL, 0, 4, 'COMPLETED', 'S-004', 1, 2, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
(11, '2026-09-30 18:58:50.000000', '2026-09-30 18:58:56.000000', '2026-09-30 18:59:20.000000', 'sahilforread@gmail.com', 2, 'Sahil', NULL, 0, 5, 'COMPLETED', 'S-005', 1, 2, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
(12, '2026-09-30 19:01:16.000000', '2026-09-30 19:03:03.000000', '2026-09-30 19:09:34.000000', 'sahilforread@gmail.com', 2, 'Sahil', NULL, 0, 6, 'COMPLETED', 'S-006', 1, 2, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
(13, '2026-09-30 19:10:24.000000', NULL, '2026-09-30 19:10:56.000000', 'sahilforread@gmail.com', 2, 'Sahil', NULL, 0, 7, 'COMPLETED', 'S-007', 1, 2, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
(14, '2026-09-30 19:11:19.000000', NULL, '2026-10-01 07:29:25.000000', 'sahilforread@gmail.com', 2, 'Sahil', NULL, 0, 8, 'COMPLETED', 'S-008', 1, 2, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
(16, '2026-10-01 16:06:38.000000', NULL, '2026-10-01 16:07:13.000000', 'sahilforread@gmail.com', 2, 'Sahil', NULL, 0, 1, 'COMPLETED', 'S-001', 1, 2, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
(18, '2026-10-01 16:10:18.000000', '2026-10-01 16:10:23.000000', '2026-10-01 16:11:04.000000', 'sahilforread@gmail.com', 2, 'Sahil', NULL, 0, 2, 'COMPLETED', 'S-002', 1, 2, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
(19, '2026-10-01 16:16:11.000000', '2026-10-01 16:16:22.000000', '2026-10-01 16:16:40.000000', 'sahilforread@gmail.com', 2, 'Sahil', NULL, 0, 3, 'COMPLETED', 'S-003', 1, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
(21, '2026-10-01 16:43:27.000000', NULL, '2026-10-01 16:45:11.000000', 'sahilforread@gmail.com', 2, 'Sahil', NULL, 0, 4, 'COMPLETED', 'S-004', 1, 2, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
(22, '2026-10-01 16:45:26.000000', NULL, NULL, 'sahilforread@gmail.com', 2, 'Sahil', NULL, 0, 5, 'CANCELLED', 'S-005', 1, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
(23, '2026-10-01 17:37:31.000000', NULL, '2026-10-01 17:38:58.000000', 'sahilforread@gmail.com', 2, 'Sahil', NULL, 0, 6, 'COMPLETED', 'S-006', 1, 2, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
(24, '2026-10-01 17:39:18.000000', '2026-10-01 17:39:37.000000', '2026-10-01 17:39:50.000000', 'sahilforread@gmail.com', 2, 'Sahil', NULL, 0, 7, 'COMPLETED', 'S-007', 1, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
(25, '2026-10-01 17:45:21.000000', NULL, NULL, 'sahilforread@gmail.com', 2, 'Sahil', NULL, 0, 8, 'CANCELLED', 'S-008', 1, 2, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
(26, '2026-10-01 21:30:40.000000', NULL, '2026-10-02 08:34:10.000000', 'sahilforread@gmail.com', 2, 'Sahil', NULL, 0, 9, 'COMPLETED', 'S-009', 1, 2, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
(27, '2026-10-02 09:50:45.000000', NULL, NULL, 'sahilforread@gmail.com', 2, 'Sahil', NULL, 0, 1, 'SKIPPED', 'S-001', 1, 2, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
(28, '2026-10-02 09:52:44.000000', NULL, '2026-10-02 12:31:02.000000', 'sahilforread@gmail.com', 2, 'Sahil', NULL, 0, 2, 'COMPLETED', 'S-002', 1, 2, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
(29, '2026-10-02 12:31:33.000000', NULL, '2026-10-02 12:33:30.000000', 'sahilforread@gmail.com', 2, 'Sahil', NULL, 0, 3, 'COMPLETED', 'S-003', 1, 2, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
(30, '2026-10-02 12:33:45.000000', NULL, '2026-10-02 12:40:57.000000', 'sahilforread@gmail.com', 2, 'Sahil', NULL, 0, 4, 'COMPLETED', 'S-004', 1, 2, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
(31, '2026-10-02 12:41:39.000000', '2026-10-02 12:43:57.000000', '2026-10-02 12:45:53.000000', 'sahilforread@gmail.com', 2, 'Sahil', NULL, 0, 5, 'COMPLETED', 'S-005', 1, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
(32, '2026-10-02 12:46:22.000000', NULL, '2026-10-02 13:10:16.000000', 'sahilforread@gmail.com', 2, 'Sahil', NULL, 0, 6, 'COMPLETED', 'S-006', 1, 2, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
(33, '2026-10-02 13:10:48.000000', NULL, '2026-10-02 13:12:56.000000', 'sahilforread@gmail.com', 2, 'Sahil', NULL, 0, 7, 'COMPLETED', 'S-007', 1, 2, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
(34, '2026-10-02 13:21:11.000000', NULL, '2026-10-02 13:21:57.000000', 'sahilforread@gmail.com', 2, 'Sahil', NULL, 0, 8, 'COMPLETED', 'S-008', 1, 2, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
(35, '2026-10-02 13:23:58.000000', NULL, '2026-10-02 13:48:17.000000', 'sahilforread@gmail.com', 2, 'Sahil', NULL, 0, 9, 'COMPLETED', 'S-009', 1, 2, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
(36, '2026-10-02 13:48:33.000000', '2026-10-02 13:48:50.000000', '2026-10-02 13:48:54.000000', 'sahilforread@gmail.com', 2, 'Sahil', NULL, 0, 10, 'COMPLETED', 'S-010', 1, NULL, 'REJECTED', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
(37, '2026-10-02 14:08:57.000000', NULL, '2026-10-02 14:09:07.000000', 'sahilforread@gmail.com', 2, 'Sahil', NULL, 0, 11, 'COMPLETED', 'S-011', 1, 2, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
(38, '2026-10-02 18:25:01.000000', NULL, '2026-10-02 18:26:15.000000', 'sahilforread@gmail.com', 2, 'Sahil', NULL, 0, 12, 'COMPLETED', 'S-012', 1, 2, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
(39, '2026-10-02 18:25:25.000000', NULL, '2026-10-02 18:26:42.000000', 'sahilforxyz@gmail.com', 3, 'Sahil Kumar', NULL, 12, 13, 'COMPLETED', 'S-013', 1, 2, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
(40, '2026-10-02 18:26:54.000000', NULL, '2026-10-02 18:27:30.000000', 'sahilforread@gmail.com', 2, 'Sahil', NULL, 0, 14, 'COMPLETED', 'S-014', 1, 2, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
(41, '2026-10-02 18:27:06.000000', NULL, '2026-10-02 18:28:06.000000', 'sahilforxyz@gmail.com', 3, 'Sahil Kumar', NULL, 12, 15, 'COMPLETED', 'S-015', 1, 2, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
(42, '2026-10-02 18:28:48.000000', '2026-10-02 18:28:51.000000', '2026-10-02 18:29:08.000000', 'sahilforxyz@gmail.com', 3, 'Sahil Kumar', NULL, 0, 16, 'COMPLETED', 'S-016', 1, 2, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
(43, '2026-10-02 19:05:31.000000', NULL, '2026-10-02 19:05:40.000000', 'sahilforxyz@gmail.com', 3, 'Sahil Kumar', NULL, 0, 17, 'COMPLETED', 'S-017', 1, 2, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
(44, '2026-10-02 19:08:55.000000', NULL, '2026-10-02 19:09:15.000000', 'sahilforxyz@gmail.com', 3, 'Sahil Kumar', NULL, 0, 18, 'COMPLETED', 'S-018', 1, 2, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
(45, '2026-10-02 19:14:39.000000', NULL, '2026-10-02 19:14:46.000000', 'sahilforxyz@gmail.com', 3, 'Sahil Kumar', NULL, 0, 19, 'COMPLETED', 'S-019', 1, 2, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
(46, '2026-10-02 19:20:21.000000', NULL, '2026-10-02 19:20:33.000000', 'sahilforxyz@gmail.com', 3, 'Sahil Kumar', NULL, 0, 20, 'COMPLETED', 'S-020', 1, 2, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
(47, '2026-10-02 19:20:47.000000', NULL, '2026-10-02 19:21:17.000000', 'sahilforxyz@gmail.com', 3, 'Sahil Kumar', NULL, 0, 21, 'COMPLETED', 'S-021', 1, 2, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
(48, '2026-10-03 17:10:11.000000', NULL, '2026-10-03 17:10:45.000000', 'sahilforread@gmail.com', 2, 'Sahil', NULL, 0, 1, 'COMPLETED', 'S-001', 1, 2, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
(49, '2026-10-03 17:10:59.000000', NULL, '2026-10-03 17:11:42.000000', 'sahilforread@gmail.com', 2, 'Sahil', NULL, 0, 2, 'COMPLETED', 'S-002', 1, 2, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
(50, '2026-10-03 17:17:05.000000', NULL, '2026-10-03 17:17:17.000000', 'sahilforread@gmail.com', 2, 'Sahil', NULL, 0, 3, 'COMPLETED', 'S-003', 1, 3, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
(51, '2026-10-03 17:18:04.000000', NULL, '2026-10-03 17:18:28.000000', 'sahilforread@gmail.com', 2, 'Sahil', NULL, 0, 4, 'COMPLETED', 'S-004', 1, 2, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
(52, '2026-10-03 17:28:17.000000', NULL, '2026-10-03 17:28:29.000000', 'sahilforread@gmail.com', 2, 'Sahil', NULL, 0, 5, 'COMPLETED', 'S-005', 1, 2, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
(53, '2026-10-03 17:36:03.000000', NULL, NULL, 'sahilforxyz@gmail.com', 3, 'Sahil Kumar', NULL, 0, 6, 'SKIPPED', 'S-006', 1, 2, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
(54, '2026-10-03 17:36:28.000000', NULL, '2026-10-03 17:39:05.000000', 'sahilforread@gmail.com', 2, 'Sahil', NULL, 12, 7, 'COMPLETED', 'S-007', 1, 2, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
(55, '2026-10-03 17:38:09.000000', '2026-10-03 17:39:05.000000', '2026-10-03 17:39:16.000000', 'sahilforxyz@gmail.com', 3, 'Sahil Kumar', NULL, 12, 8, 'COMPLETED', 'S-008', 1, 2, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
(56, '2026-10-03 17:40:27.000000', NULL, '2026-10-03 17:41:31.000000', 'sahilforxyz@gmail.com', 3, 'Sahil Kumar', NULL, 0, 9, 'COMPLETED', 'S-009', 1, 2, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
(57, '2026-10-03 17:40:37.000000', NULL, '2026-10-03 17:41:40.000000', 'sahilforread@gmail.com', 2, 'Sahil', NULL, 12, 10, 'COMPLETED', 'S-010', 1, 2, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
(58, '2026-10-03 17:42:08.000000', '2026-10-03 17:42:47.000000', '2026-10-03 17:45:27.000000', 'sahilforxyz@gmail.com', 3, 'Sahil Kumar', NULL, 0, 11, 'COMPLETED', 'S-011', 1, 2, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
(59, '2026-10-03 17:42:15.000000', NULL, '2026-10-03 18:03:07.000000', 'sahilforread@gmail.com', 2, 'Sahil', NULL, 12, 13, 'COMPLETED', 'S-012', 1, 2, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
(60, '2026-10-03 18:02:30.000000', '2026-10-03 18:02:47.000000', '2026-10-03 18:02:58.000000', 'sahilforxyz@gmail.com', 3, 'Sahil Kumar', NULL, 12, 12, 'COMPLETED', 'S-013', 1, 2, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
(61, '2026-10-03 19:20:25.000000', NULL, '2026-10-03 19:20:51.000000', 'sahilforxyz@gmail.com', 3, 'Sahil Kumar', NULL, 0, 14, 'COMPLETED', 'S-014', 1, 2, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
(62, '2026-10-03 19:33:01.000000', NULL, '2026-10-03 19:33:29.000000', 'sahilforxyz@gmail.com', 3, 'Sahil Kumar', NULL, 0, 15, 'COMPLETED', 'S-015', 1, 2, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
(63, '2026-10-03 19:38:21.000000', NULL, NULL, 'sahilforxyz@gmail.com', 3, 'Sahil Kumar', NULL, 0, 1, 'CANCELLED', 'C-001', 2, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
(64, '2026-10-03 19:38:57.000000', NULL, '2026-10-03 19:39:17.000000', 'sahilforxyz@gmail.com', 3, 'Sahil Kumar', NULL, 0, 16, 'COMPLETED', 'S-016', 1, 2, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
(65, '2026-10-03 19:40:00.000000', NULL, '2026-10-03 19:40:13.000000', 'sahilforxyz@gmail.com', 3, 'Sahil Kumar', NULL, 0, 17, 'COMPLETED', 'S-017', 1, 2, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
(66, '2026-10-03 21:05:36.000000', '2026-10-03 21:05:41.000000', '2026-10-03 21:05:56.000000', 'sahilforread@gmail.com', 2, 'Sahil', NULL, 0, 18, 'COMPLETED', 'S-018', 1, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
(67, '2026-10-06 18:27:49.000000', NULL, '2026-10-06 18:28:47.000000', 'sahilforread@gmail.com', 2, 'Sahil', NULL, 0, 1, 'COMPLETED', 'S-001', 1, 2, NULL, NULL, 1, 53, '2026-10-06 18:27:54.000000', NULL, NULL, NULL, NULL, NULL),
(68, '2026-10-07 17:11:24.000000', NULL, '2026-10-07 17:11:30.000000', 'sahilforread@gmail.com', 2, 'Sahil', NULL, 0, 1, 'COMPLETED', 'S-001', 1, 2, NULL, NULL, 0, 1, '2026-10-07 17:11:29.000000', NULL, NULL, NULL, NULL, NULL),
(69, '2026-10-07 17:28:26.000000', NULL, '2026-10-07 17:28:34.000000', 'sahilforread@gmail.com', 2, 'Sahil', NULL, 0, 2, 'COMPLETED', 'S-002', 1, 2, NULL, NULL, 0, 2, '2026-10-07 17:28:32.000000', NULL, NULL, NULL, NULL, NULL),
(70, '2026-10-07 17:35:23.000000', NULL, '2026-10-07 17:37:21.000000', 'sahilforread@gmail.com', 2, 'Sahil', NULL, 0, 3, 'COMPLETED', 'S-003', 1, 2, NULL, NULL, 2, 113, '2026-10-07 17:35:28.000000', NULL, NULL, NULL, NULL, NULL),
(71, '2026-10-09 16:41:59.000000', NULL, '2026-10-09 16:43:08.000000', 'sahilforread@gmail.com', 2, 'Sahil', NULL, 0, 1, 'COMPLETED', 'S-001', 1, 2, NULL, NULL, 0, 9, '2026-10-09 16:42:59.000000', NULL, NULL, NULL, NULL, NULL),
(72, '2026-10-09 16:48:35.000000', NULL, '2026-10-09 17:03:00.000000', 'sahilforread@gmail.com', 2, 'Sahil', NULL, 0, 2, 'COMPLETED', 'S-002', 1, 2, NULL, NULL, 1, 37, '2026-10-09 17:02:23.000000', NULL, NULL, NULL, NULL, NULL),
(73, '2026-10-09 17:05:28.000000', NULL, '2026-10-09 17:05:56.000000', 'sahilforread@gmail.com', 2, 'Sahil', NULL, 0, 3, 'COMPLETED', 'S-003', 1, 2, NULL, NULL, 0, 5, '2026-10-09 17:05:51.000000', 'bread', NULL, NULL, NULL, NULL),
(74, '2026-10-09 17:09:06.000000', NULL, '2026-10-09 17:09:13.000000', 'sahilforread@gmail.com', 2, 'Sahil', NULL, 0, 4, 'COMPLETED', 'S-004', 1, 2, NULL, NULL, 0, 2, '2026-10-09 17:09:11.000000', NULL, NULL, NULL, NULL, NULL),
(75, '2026-10-09 17:34:56.000000', NULL, '2026-10-09 17:35:22.000000', 'sahilforread@gmail.com', 2, 'Sahil', NULL, 0, 5, 'COMPLETED', 'S-005', 1, 2, NULL, NULL, 0, 7, '2026-10-09 17:35:15.000000', 'head massage', b'0', NULL, NULL, 'NONE'),
(76, '2026-10-09 17:39:58.000000', NULL, '2026-10-09 17:41:00.000000', 'sahilforread@gmail.com', 2, 'Sahil', NULL, 0, 6, 'COMPLETED', 'S-006', 1, 2, NULL, NULL, 0, 2, '2026-10-09 17:40:58.000000', 'haircut', b'1', 'because i have pressure to go to toilet', '2026-10-09 17:40:25.000000', 'ACCEPTED'),
(77, '2026-10-09 17:41:12.000000', NULL, '2026-10-09 17:41:42.000000', 'sahilforread@gmail.com', 2, 'Sahil', NULL, 0, 7, 'COMPLETED', 'S-007', 1, 2, NULL, NULL, 0, 2, '2026-10-09 17:41:40.000000', NULL, b'1', 'i got toilet', '2026-10-09 17:41:21.000000', 'ACCEPTED'),
(78, '2026-10-11 15:49:09.000000', NULL, '2026-10-11 15:50:15.000000', 'sahilforread@gmail.com', 2, 'Sahil', NULL, 0, 1, 'COMPLETED', 'S-001', 1, 2, NULL, NULL, 0, 17, '2026-10-11 15:49:58.000000', NULL, b'0', NULL, NULL, 'NONE'),
(79, '2026-10-11 15:49:31.000000', NULL, '2026-10-11 15:50:55.000000', 'sahilforxyz@gmail.com', 3, 'Sahil Kumar', NULL, 12, 2, 'COMPLETED', 'S-002', 1, 2, NULL, NULL, 1, 38, '2026-10-11 15:50:17.000000', NULL, b'0', NULL, NULL, 'NONE'),
(80, '2026-10-11 16:31:35.000000', NULL, '2026-10-11 16:32:11.000000', 'sahilforread@gmail.com', 2, 'Sahil', NULL, 0, 1, 'COMPLETED', 'C-001', 3, 4, NULL, NULL, 0, 7, '2026-10-11 16:32:04.000000', NULL, b'0', NULL, NULL, 'NONE'),
(81, '2026-10-11 16:31:55.000000', NULL, '2026-10-11 16:32:21.000000', 'sahilforxyz@gmail.com', 3, 'Sahil Kumar', NULL, 12, 2, 'COMPLETED', 'C-002', 3, 4, NULL, NULL, 0, 6, '2026-10-11 16:32:15.000000', NULL, b'0', NULL, NULL, 'NONE'),
(82, '2026-10-11 16:39:35.000000', NULL, '2026-10-11 16:39:57.000000', 'sahilforxyz@gmail.com', 3, 'Sahil Kumar', NULL, 0, 3, 'COMPLETED', 'C-003', 3, 4, NULL, NULL, 0, 18, '2026-10-11 16:39:39.000000', NULL, b'0', NULL, NULL, 'NONE'),
(83, '2026-10-11 17:12:15.000000', NULL, '2026-10-11 17:12:31.000000', 'sahilforxyz@gmail.com', 3, 'Sahil Kumar', NULL, 0, 3, 'COMPLETED', 'S-003', 1, 2, NULL, NULL, 0, 8, '2026-10-11 17:12:23.000000', NULL, b'0', NULL, NULL, 'NONE'),
(84, '2026-10-11 17:12:40.000000', NULL, '2026-10-11 17:12:59.000000', 'sahilforxyz@gmail.com', 3, 'Sahil Kumar', NULL, 0, 4, 'COMPLETED', 'S-004', 1, 2, NULL, NULL, 0, 13, '2026-10-11 17:12:46.000000', NULL, b'0', NULL, NULL, 'NONE'),
(85, '2026-10-11 17:14:09.000000', NULL, '2026-10-11 17:14:22.000000', 'sahilforread@gmail.com', 2, 'Sahil', NULL, 0, 5, 'COMPLETED', 'S-005', 1, 2, NULL, NULL, 0, 10, '2026-10-11 17:14:12.000000', NULL, b'0', NULL, NULL, 'NONE'),
(86, '2026-10-11 17:14:32.000000', NULL, '2026-10-11 17:14:43.000000', 'sahilforread@gmail.com', 2, 'Sahil', NULL, 0, 6, 'COMPLETED', 'S-006', 1, 2, NULL, NULL, 0, 6, '2026-10-11 17:14:37.000000', NULL, b'0', NULL, NULL, 'NONE'),
(87, '2026-10-11 17:33:22.000000', NULL, '2026-10-11 17:33:29.000000', 'sahilforread@gmail.com', 2, 'Sahil', NULL, 0, 7, 'COMPLETED', 'S-007', 1, 2, NULL, NULL, 0, 5, '2026-10-11 17:33:24.000000', NULL, b'0', NULL, NULL, 'NONE'),
(88, '2026-10-11 17:40:02.000000', NULL, '2026-10-11 17:40:23.000000', 'sahilforxyz@gmail.com', 3, 'Sahil Kumar', NULL, 0, 8, 'COMPLETED', 'S-008', 1, 2, NULL, NULL, 0, 7, '2026-10-11 17:40:16.000000', 'Bread', b'0', NULL, NULL, 'NONE'),
(89, '2026-10-11 17:41:37.000000', NULL, '2026-10-11 17:41:51.000000', 'sahilforread@gmail.com', 2, 'Sahil', NULL, 0, 9, 'COMPLETED', 'S-009', 1, 2, NULL, NULL, 0, 6, '2026-10-11 17:41:45.000000', 'hello', b'0', NULL, NULL, 'NONE'),
(90, '2026-10-18 08:55:11.000000', '2026-10-18 08:55:19.000000', '2026-10-18 08:55:39.000000', 'sahilforread@gmail.com', 2, 'Sahil', NULL, 0, 1, 'COMPLETED', 'S-001', 1, NULL, NULL, NULL, 0, 20, '2026-10-18 08:55:19.000000', 'bread', b'0', NULL, NULL, 'NONE'),
(91, '2026-10-18 08:55:52.000000', '2026-10-18 08:56:03.000000', '2026-10-18 08:59:26.000000', 'sahilforread@gmail.com', 2, 'Sahil', NULL, 0, 2, 'COMPLETED', 'S-002', 1, NULL, NULL, NULL, 3, 203, '2026-10-18 08:56:03.000000', 'bread', b'0', NULL, NULL, 'NONE'),
(92, '2026-10-18 08:58:57.000000', NULL, '2026-10-18 12:56:53.000000', 'sp9925438084@gmail.com', 4, 'sahil parmar', NULL, 0, 3, 'COMPLETED', 'S-003', 1, 2, NULL, NULL, 0, 8, '2026-10-18 12:56:45.000000', 'Haircut', b'0', NULL, NULL, 'NONE'),
(93, '2026-10-18 08:59:43.000000', NULL, '2026-10-18 12:57:07.000000', 'sahilforread@gmail.com', 2, 'Sahil', NULL, 12, 4, 'COMPLETED', 'S-004', 1, 2, NULL, NULL, 0, 1, '2026-10-18 12:57:06.000000', '54', b'0', NULL, NULL, 'NONE'),
(94, '2026-10-18 09:21:55.000000', NULL, NULL, 'sp9925438084@gmail.com', 4, 'sahil parmar', NULL, 0, 1, 'CANCELLED', 'C-001', 2, NULL, NULL, NULL, NULL, NULL, NULL, 'Bjj', b'0', NULL, NULL, 'NONE'),
(95, '2026-10-18 12:57:34.000000', NULL, '2026-10-18 13:01:56.000000', 'sp9925438084@gmail.com', 4, 'sahil parmar', NULL, 0, 5, 'COMPLETED', 'S-005', 1, 2, NULL, NULL, 4, 235, '2026-10-18 12:58:01.000000', NULL, b'0', NULL, NULL, 'NONE'),
(96, '2026-10-18 12:57:43.000000', NULL, '2026-10-18 13:02:08.000000', 'sahilforread@gmail.com', 2, 'Sahil', NULL, 1, 6, 'COMPLETED', 'S-006', 1, 2, NULL, NULL, 0, 5, '2026-10-18 13:02:03.000000', NULL, b'0', NULL, NULL, 'NONE'),
(97, '2026-10-18 13:02:19.000000', NULL, NULL, 'sp9925438084@gmail.com', 4, 'sahil parmar', NULL, 0, 7, 'CANCELLED', 'S-007', 1, 2, NULL, NULL, NULL, NULL, NULL, NULL, b'0', NULL, NULL, 'NONE'),
(98, '2026-10-18 13:02:25.000000', NULL, '2026-10-20 09:31:12.000000', 'sahilforread@gmail.com', 2, 'Sahil', NULL, 2, 8, 'COMPLETED', 'S-008', 1, 2, NULL, NULL, 0, 1, '2026-10-20 09:31:11.000000', NULL, b'0', NULL, NULL, 'NONE'),
(99, '2026-10-20 09:32:20.000000', NULL, '2026-10-20 09:32:57.000000', 'sp9925438084@gmail.com', 4, 'sahil parmar', NULL, 0, 1, 'COMPLETED', 'S-001', 1, 2, NULL, NULL, 0, 6, '2026-10-20 09:32:51.000000', NULL, b'0', NULL, NULL, 'NONE'),
(100, '2026-10-20 09:32:32.000000', NULL, '2026-10-20 09:33:28.000000', 'sahilforread@gmail.com', 2, 'Sahil', NULL, 2, 2, 'COMPLETED', 'S-002', 1, 2, NULL, NULL, 0, 4, '2026-10-20 09:33:24.000000', NULL, b'0', NULL, NULL, 'NONE'),
(101, '2026-10-20 10:09:23.000000', NULL, NULL, 'sp9925438084@gmail.com', 4, 'sahil parmar', NULL, 0, 3, 'CANCELLED', 'S-003', 1, 2, NULL, NULL, NULL, NULL, NULL, NULL, b'0', NULL, NULL, 'NONE'),
(102, '2026-10-20 10:12:02.000000', NULL, '2026-10-20 10:12:19.000000', 'sp9925438084@gmail.com', 4, 'sahil parmar', NULL, 0, 4, 'COMPLETED', 'S-004', 1, 2, NULL, NULL, 0, 11, '2026-10-20 10:12:08.000000', NULL, b'0', NULL, NULL, 'NONE'),
(103, '2026-10-20 10:51:14.000000', NULL, '2026-10-20 10:52:26.000000', 'sp9925438084@gmail.com', 4, 'sahil parmar', NULL, 0, 5, 'COMPLETED', 'S-005', 1, 2, NULL, NULL, 0, 4, '2026-10-20 10:52:22.000000', NULL, b'1', 'heart attack', '2026-10-20 10:51:51.000000', 'ACCEPTED'),
(104, '2026-10-20 10:52:41.000000', NULL, NULL, 'sp9925438084@gmail.com', 4, 'sahil parmar', NULL, 0, 6, 'CANCELLED', 'S-006', 1, 2, NULL, NULL, NULL, NULL, NULL, NULL, b'0', NULL, NULL, 'NONE'),
(105, '2026-10-21 14:26:30.000000', '2026-10-21 14:26:35.000000', '2026-10-21 14:26:42.000000', 'sp9925438084@gmail.com', 4, 'sahil parmar', NULL, 0, 1, 'COMPLETED', 'S-001', 1, NULL, NULL, NULL, 0, 7, '2026-10-21 14:26:35.000000', NULL, b'0', NULL, NULL, 'NONE'),
(106, '2026-10-21 14:44:54.000000', NULL, '2026-10-21 15:02:20.000000', 'sp9925438084@gmail.com', 4, 'sahil parmar', NULL, 0, 2, 'COMPLETED', 'S-002', 1, 2, NULL, NULL, 0, 2, '2026-10-21 15:02:18.000000', NULL, b'0', NULL, NULL, 'NONE'),
(107, '2026-10-21 14:46:56.000000', NULL, '2026-10-21 15:02:23.000000', 'sahilparmarbusiness@gmail.com', 5, 'Sahil Parmar', NULL, 2, 3, 'COMPLETED', 'S-003', 1, 2, NULL, NULL, 0, 1, '2026-10-21 15:02:22.000000', NULL, b'0', NULL, NULL, 'NONE'),
(108, '2026-10-21 14:47:53.000000', NULL, '2026-10-21 15:02:25.000000', 'sahilparmarpalanpur@gmail.com', 6, 'sahil parmar', NULL, 4, 4, 'COMPLETED', 'S-004', 1, 2, NULL, NULL, 0, 1, '2026-10-21 15:02:24.000000', NULL, b'0', NULL, NULL, 'NONE'),
(109, '2026-10-21 14:48:41.000000', NULL, '2026-10-21 15:02:33.000000', '250160450047.gvp@gujaratvidyapith.org', 7, 'SAHIL PARMAR', NULL, 6, 5, 'COMPLETED', 'S-005', 1, 2, NULL, NULL, 0, 1, '2026-10-21 15:02:32.000000', NULL, b'0', NULL, NULL, 'NONE'),
(110, '2026-10-21 14:49:40.000000', '2026-10-21 15:02:35.000000', '2026-10-21 15:02:37.000000', 'sahilforxyz@gmail.com', 3, 'Sahil Kumar', NULL, 8, 6, 'COMPLETED', 'S-006', 1, 2, NULL, NULL, 0, 2, '2026-10-21 15:02:35.000000', NULL, b'0', NULL, NULL, 'NONE'),
(111, '2026-10-21 14:55:41.000000', '2026-10-21 15:02:38.000000', '2026-10-21 15:02:39.000000', 'sahilforread@gmail.com', 2, 'Sahil', NULL, 10, 7, 'COMPLETED', 'S-007', 1, 2, NULL, NULL, 0, 1, '2026-10-21 15:02:38.000000', NULL, b'0', NULL, NULL, 'NONE'),
(112, '2026-10-21 14:57:03.000000', '2026-10-21 15:02:40.000000', '2026-10-21 15:02:41.000000', 'sahilforread@gmail.com', 2, 'Sahil', NULL, 12, 8, 'COMPLETED', 'S-008', 1, 2, NULL, NULL, 0, 1, '2026-10-21 15:02:40.000000', NULL, b'0', NULL, NULL, 'NONE'),
(113, '2026-10-21 14:57:23.000000', '2026-10-21 15:02:53.000000', '2026-10-21 15:02:54.000000', 'sahilforread@gmail.com', 2, 'Sahil', NULL, 14, 9, 'COMPLETED', 'S-009', 1, 2, NULL, NULL, 0, 1, '2026-10-21 15:02:53.000000', NULL, b'0', NULL, NULL, 'NONE'),
(114, '2026-10-21 14:57:37.000000', '2026-10-21 15:02:55.000000', '2026-10-21 15:02:56.000000', 'sahilforread@gmail.com', 2, 'Sahil', NULL, 16, 10, 'COMPLETED', 'S-010', 1, 2, NULL, NULL, 0, 1, '2026-10-21 15:02:55.000000', NULL, b'0', NULL, NULL, 'NONE'),
(115, '2026-10-21 14:58:39.000000', '2026-10-21 15:02:58.000000', '2026-10-21 15:02:59.000000', 'sahilforread@gmail.com', 2, 'Sahil', NULL, 18, 11, 'COMPLETED', 'S-011', 1, 2, NULL, NULL, 0, 1, '2026-10-21 15:02:58.000000', NULL, b'0', NULL, NULL, 'NONE'),
(116, '2026-10-21 14:59:51.000000', '2026-10-21 15:03:00.000000', '2026-10-21 15:03:01.000000', 'sahilforread@gmail.com', 2, 'Sahil', NULL, 20, 12, 'COMPLETED', 'S-012', 1, 2, NULL, NULL, 0, 1, '2026-10-21 15:03:00.000000', NULL, b'0', NULL, NULL, 'NONE'),
(117, '2026-10-21 15:00:27.000000', '2026-10-21 15:03:03.000000', '2026-10-21 15:03:04.000000', 'sahilforread@gmail.com', 2, 'Sahil', NULL, 22, 13, 'COMPLETED', 'S-013', 1, 2, NULL, NULL, 0, 1, '2026-10-21 15:03:03.000000', NULL, b'0', NULL, NULL, 'NONE'),
(118, '2026-10-21 15:00:39.000000', '2026-10-21 15:03:05.000000', '2026-10-21 15:03:06.000000', 'sahilforread@gmail.com', 2, 'Sahil', NULL, 24, 14, 'COMPLETED', 'S-014', 1, 2, NULL, NULL, 0, 1, '2026-10-21 15:03:05.000000', NULL, b'0', NULL, NULL, 'NONE'),
(119, '2026-10-21 15:00:55.000000', '2026-10-21 15:03:07.000000', '2026-10-21 15:03:09.000000', 'sahilforread@gmail.com', 2, 'Sahil', NULL, 26, 15, 'COMPLETED', 'S-015', 1, 2, NULL, NULL, 0, 2, '2026-10-21 15:03:07.000000', NULL, b'0', NULL, NULL, 'NONE'),
(120, '2026-10-21 15:01:06.000000', '2026-10-21 15:03:09.000000', '2026-10-21 15:03:10.000000', 'sahilforread@gmail.com', 2, 'Sahil', NULL, 28, 16, 'COMPLETED', 'S-016', 1, 2, NULL, NULL, 0, 1, '2026-10-21 15:03:09.000000', NULL, b'0', NULL, NULL, 'NONE'),
(121, '2026-10-21 15:01:17.000000', '2026-10-21 15:03:11.000000', '2026-10-21 15:03:12.000000', 'sahilforread@gmail.com', 2, 'Sahil', NULL, 30, 17, 'COMPLETED', 'S-017', 1, 2, NULL, NULL, 0, 1, '2026-10-21 15:03:11.000000', NULL, b'0', NULL, NULL, 'NONE'),
(122, '2026-10-21 15:01:36.000000', NULL, NULL, 'sahilforread@gmail.com', 2, 'Sahil', NULL, 32, 18, 'CANCELLED', 'S-018', 1, 3, NULL, NULL, NULL, NULL, NULL, NULL, b'0', NULL, NULL, 'NONE'),
(123, '2026-10-21 15:01:58.000000', NULL, '2026-10-21 15:03:41.000000', 'sahilforread@gmail.com', 2, 'Sahil', NULL, 34, 19, 'COMPLETED', 'S-019', 1, 2, NULL, NULL, 0, 2, '2026-10-21 15:03:39.000000', '546', b'0', NULL, NULL, 'NONE'),
(124, '2026-10-21 15:04:27.000000', NULL, '2026-10-21 15:04:53.000000', 'sahilforxyz@gmail.com', 3, 'Sahil Kumar', NULL, 2, 20, 'COMPLETED', 'S-020', 1, 2, NULL, NULL, 0, 7, '2026-10-21 15:04:46.000000', 'Jsj', b'0', NULL, NULL, 'NONE'),
(125, '2026-10-21 15:43:13.000000', NULL, '2026-10-21 15:44:03.000000', 'sahilforread@gmail.com', 2, 'Sahil', NULL, 0, 21, 'COMPLETED', 'S-021', 1, 2, NULL, NULL, 0, 6, '2026-10-21 15:43:57.000000', NULL, b'0', NULL, NULL, 'NONE'),
(126, '2026-10-21 15:46:09.000000', NULL, '2026-10-21 16:03:41.000000', 'sahilforread@gmail.com', 2, 'Sahil', NULL, 0, 22, 'COMPLETED', 'S-022', 1, 2, NULL, NULL, 0, 2, '2026-10-21 16:03:39.000000', NULL, b'0', NULL, NULL, 'NONE'),
(127, '2026-10-21 15:46:30.000000', NULL, NULL, 'sahilforread@gmail.com', 2, 'Sahil', NULL, 0, 1, 'CANCELLED', 'C-001', 2, NULL, NULL, NULL, NULL, NULL, NULL, 'asdf', b'0', NULL, NULL, 'NONE'),
(128, '2026-10-21 15:47:32.000000', NULL, NULL, 'sahilforxyz@gmail.com', 3, 'Sahil Kumar', NULL, 2, 23, 'CANCELLED', 'S-023', 1, 2, NULL, NULL, NULL, NULL, NULL, NULL, b'0', NULL, NULL, 'NONE'),
(129, '2026-10-21 16:02:29.000000', NULL, '2026-10-21 16:03:45.000000', 'sahilforxyz@gmail.com', 3, 'Sahil Kumar', NULL, 2, 24, 'COMPLETED', 'S-024', 1, 2, NULL, NULL, 0, 3, '2026-10-21 16:03:42.000000', NULL, b'0', NULL, NULL, 'NONE'),
(130, '2026-10-21 16:53:29.000000', NULL, '2026-10-21 16:53:40.000000', 'sahilforxyz@gmail.com', 3, 'Sahil Kumar', NULL, 0, 25, 'COMPLETED', 'S-025', 1, 2, NULL, NULL, 0, 6, '2026-10-21 16:53:34.000000', NULL, b'0', NULL, NULL, 'NONE'),
(131, '2026-10-21 17:05:15.000000', NULL, '2026-10-21 17:05:22.000000', 'sahilforxyz@gmail.com', 3, 'Sahil Kumar', NULL, 0, 26, 'COMPLETED', 'S-026', 1, 2, NULL, NULL, 0, 1, '2026-10-21 17:05:21.000000', NULL, b'0', NULL, NULL, 'NONE'),
(132, '2026-10-21 17:06:03.000000', NULL, '2026-10-21 17:06:20.000000', 'sahilforxyz@gmail.com', 3, 'Sahil Kumar', NULL, 0, 27, 'COMPLETED', 'S-027', 1, 2, NULL, NULL, 0, 1, '2026-10-21 17:06:19.000000', 'Hello', b'0', NULL, NULL, 'NONE'),
(133, '2026-10-21 17:06:39.000000', '2026-10-21 17:06:43.000000', '2026-10-21 17:06:48.000000', 'sahilforxyz@gmail.com', 3, 'Sahil Kumar', NULL, 0, 28, 'COMPLETED', 'S-028', 1, NULL, NULL, NULL, 0, 5, '2026-10-21 17:06:43.000000', 'Dg', b'0', NULL, NULL, 'NONE'),
(134, '2026-10-21 17:23:02.000000', NULL, '2026-10-21 17:27:43.000000', 'sahilforread@gmail.com', 2, 'Sahil', NULL, 0, 29, 'COMPLETED', 'S-029', 1, 2, NULL, NULL, 0, 4, '2026-10-21 17:27:39.000000', NULL, b'0', NULL, NULL, 'NONE'),
(135, '2026-10-21 17:24:23.000000', NULL, '2026-10-21 17:27:54.000000', 'sahilforxyz@gmail.com', 3, 'Sahil Kumar', NULL, 2, 30, 'COMPLETED', 'S-030', 1, 2, NULL, NULL, 0, 9, '2026-10-21 17:27:45.000000', NULL, b'0', NULL, NULL, 'NONE'),
(136, '2026-10-21 17:32:22.000000', NULL, '2026-10-21 17:42:01.000000', 'sahilforread@gmail.com', 2, 'Sahil', NULL, 0, 31, 'COMPLETED', 'S-031', 1, 2, NULL, NULL, 0, 1, '2026-10-21 17:42:00.000000', NULL, b'0', NULL, NULL, 'NONE'),
(137, '2026-10-21 17:40:58.000000', NULL, '2026-10-21 17:42:04.000000', 'sahilforxyz@gmail.com', 3, 'Sahil Kumar', NULL, 2, 32, 'COMPLETED', 'S-032', 1, 2, NULL, NULL, 0, 1, '2026-10-21 17:42:03.000000', NULL, b'0', NULL, NULL, 'NONE');

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
(4, '2026-10-03 18:38:13.000000', 'sp9925438084@gmail.com', b'1', 'pTfMZIdrefO5kic7PLAih9UieM93', 'sahil parmar', 'OFF-4BF5QT', NULL, 'CUSTOMER', '2026-10-18 08:58:25.000000'),
(5, '2026-10-11 15:53:14.000000', 'sahilparmarbusiness@gmail.com', b'1', '1r5zZtnznjVsuImHXo0jrmFZ1la2', 'Sahil Parmar', 'OFF-7DLB4E', NULL, 'CUSTOMER', '2026-10-21 14:46:30.000000'),
(6, '2026-10-21 14:47:32.000000', 'sahilparmarpalanpur@gmail.com', b'1', 'nNnNIcUoryaGcl66z9YBNW8lccp1', 'sahil parmar', NULL, NULL, 'CUSTOMER', '2026-10-21 14:47:32.000000'),
(7, '2026-10-21 14:48:27.000000', '250160450047.gvp@gujaratvidyapith.org', b'1', 'TshRGI3GZRZxYpnULXWilOiVuT83', 'SAHIL PARMAR', NULL, NULL, 'CUSTOMER', '2026-10-21 14:48:27.000000');

--
-- Indexes for dumped tables
--

--
-- Indexes for table `customer_favorite_offices`
--
ALTER TABLE `customer_favorite_offices`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `UKomkj2axjol5rq6ql39gug4xir` (`customer_id`,`office_id`),
  ADD KEY `FK4do0m8xby9omrb40tye89ts8e` (`office_id`);

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
-- AUTO_INCREMENT for table `customer_favorite_offices`
--
ALTER TABLE `customer_favorite_offices`
  MODIFY `id` bigint(20) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=6;

--
-- AUTO_INCREMENT for table `office_documents`
--
ALTER TABLE `office_documents`
  MODIFY `id` bigint(20) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=6;

--
-- AUTO_INCREMENT for table `office_profiles`
--
ALTER TABLE `office_profiles`
  MODIFY `id` bigint(20) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

--
-- AUTO_INCREMENT for table `providers`
--
ALTER TABLE `providers`
  MODIFY `id` bigint(20) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=5;

--
-- AUTO_INCREMENT for table `provider_schedules`
--
ALTER TABLE `provider_schedules`
  MODIFY `id` bigint(20) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=37;

--
-- AUTO_INCREMENT for table `queue_tokens`
--
ALTER TABLE `queue_tokens`
  MODIFY `id` bigint(20) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=138;

--
-- AUTO_INCREMENT for table `users`
--
ALTER TABLE `users`
  MODIFY `id` bigint(20) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=8;

--
-- Constraints for dumped tables
--

--
-- Constraints for table `customer_favorite_offices`
--
ALTER TABLE `customer_favorite_offices`
  ADD CONSTRAINT `FK4do0m8xby9omrb40tye89ts8e` FOREIGN KEY (`office_id`) REFERENCES `office_profiles` (`id`);

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
