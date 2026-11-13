-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Host: 127.0.0.1
-- Generation Time: Nov 10, 2026 at 04:24 PM
-- Server version: 10.4.32-MariaDB
-- PHP Version: 8.0.30

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `ecoride_db`
--

DELIMITER $$
--
-- Procedures
--
DROP PROCEDURE IF EXISTS `sp_adjust_credit`$$
CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_adjust_credit` (IN `p_user_id` INT UNSIGNED, IN `p_amount` DECIMAL(10,2), IN `p_type` VARCHAR(20), IN `p_note` VARCHAR(255))   BEGIN
  DECLARE v_credit DECIMAL(10,2);

  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;

  START TRANSACTION;

  IF p_type NOT IN ('refund','adjustment') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Type must be refund or adjustment';
  END IF;
  IF p_amount = 0 OR (p_type = 'refund' AND p_amount < 0) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid amount';
  END IF;
  IF p_note IS NULL OR TRIM(p_note) = '' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Please give a reason';
  END IF;

  SELECT credit_balance INTO v_credit FROM users WHERE user_id = p_user_id FOR UPDATE;
  IF v_credit IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'User not found';
  END IF;
  IF v_credit + p_amount < 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Credit cannot go below 0';
  END IF;

  UPDATE users SET credit_balance = v_credit + p_amount WHERE user_id = p_user_id;
  INSERT INTO credit_transactions (user_id, txn_type, amount, balance_after, note)
  VALUES (p_user_id, p_type, p_amount, v_credit + p_amount, TRIM(p_note));

  COMMIT;
END$$

DROP PROCEDURE IF EXISTS `sp_borrow_vehicle`$$
CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_borrow_vehicle` (IN `p_user_id` INT UNSIGNED, IN `p_vehicle_id` INT UNSIGNED, IN `p_plan_id` TINYINT UNSIGNED, OUT `p_ride_id` BIGINT UNSIGNED)   BEGIN
  DECLARE v_credit  DECIMAL(10,2);
  DECLARE v_balance DECIMAL(10,2);
  DECLARE v_price   DECIMAL(10,2);
  DECLARE v_hours   SMALLINT UNSIGNED;
  DECLARE v_status  VARCHAR(20);
  DECLARE v_station INT UNSIGNED;
  DECLARE v_battery TINYINT UNSIGNED;
  DECLARE v_code    VARCHAR(10);
  DECLARE v_open    INT DEFAULT 0;

  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;

  START TRANSACTION;

  SELECT credit_balance INTO v_credit
    FROM users WHERE user_id = p_user_id AND is_active = 1 FOR UPDATE;
  IF v_credit IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'User not found or inactive';
  END IF;

  SELECT COUNT(*) INTO v_open
    FROM rides WHERE user_id = p_user_id AND status IN ('active','overdue');
  IF v_open > 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'You already have a vehicle borrowed';
  END IF;

  SELECT price, duration_hours INTO v_price, v_hours
    FROM rental_plans WHERE plan_id = p_plan_id AND is_active = 1;
  IF v_price IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Rental plan not found';
  END IF;

  SELECT status, current_station_id, battery_level, vehicle_code
    INTO v_status, v_station, v_battery, v_code
    FROM vehicles WHERE vehicle_id = p_vehicle_id FOR UPDATE;
  IF v_status IS NULL OR v_status <> 'available' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Vehicle is not available';
  END IF;
  IF v_battery < 20 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Battery too low to borrow';
  END IF;
  IF v_credit < v_price THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Not enough credit';
  END IF;

  SET v_balance = v_credit - v_price;

  INSERT INTO rides (user_id, vehicle_id, plan_id, start_station_id,
                     start_time, due_time, battery_start, price_paid, status)
  VALUES (p_user_id, p_vehicle_id, p_plan_id, v_station,
          NOW(), DATE_ADD(NOW(), INTERVAL v_hours HOUR), v_battery, v_price, 'active');
  SET p_ride_id = LAST_INSERT_ID();

  UPDATE users    SET credit_balance = v_balance WHERE user_id = p_user_id;
  UPDATE vehicles SET status = 'in_use', current_station_id = NULL, battery_updated_at = NOW()
   WHERE vehicle_id = p_vehicle_id;

  INSERT INTO credit_transactions (user_id, txn_type, amount, balance_after, ride_id, note)
  VALUES (p_user_id, 'ride_payment', -v_price, v_balance, p_ride_id, CONCAT('Ride ', v_code));

  COMMIT;
END$$

DROP PROCEDURE IF EXISTS `sp_confirm_topup`$$
CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_confirm_topup` (IN `p_topup_id` INT UNSIGNED)   BEGIN
  DECLARE v_user    INT UNSIGNED;
  DECLARE v_amount  DECIMAL(10,2);
  DECLARE v_balance DECIMAL(10,2);

  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;

  START TRANSACTION;

  SELECT user_id, amount INTO v_user, v_amount
    FROM topups WHERE topup_id = p_topup_id AND status = 'pending' FOR UPDATE;
  IF v_user IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Top-up not found or not pending';
  END IF;

  UPDATE topups SET status = 'paid', paid_at = NOW() WHERE topup_id = p_topup_id;
  UPDATE users  SET credit_balance = credit_balance + v_amount WHERE user_id = v_user;
  SELECT credit_balance INTO v_balance FROM users WHERE user_id = v_user;

  INSERT INTO credit_transactions (user_id, txn_type, amount, balance_after, topup_id, note)
  VALUES (v_user, 'topup', v_amount, v_balance, p_topup_id, 'Top up');

  COMMIT;
END$$

DROP PROCEDURE IF EXISTS `sp_mark_overdue`$$
CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_mark_overdue` ()   BEGIN
  UPDATE rides SET status = 'overdue'
   WHERE status = 'active' AND due_time < NOW();
END$$

DROP PROCEDURE IF EXISTS `sp_return_vehicle`$$
CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_return_vehicle` (IN `p_ride_id` BIGINT UNSIGNED, IN `p_station_id` INT UNSIGNED, IN `p_battery_end` TINYINT UNSIGNED)   BEGIN
  DECLARE v_vehicle INT UNSIGNED;
  DECLARE v_start   INT UNSIGNED;
  DECLARE v_docks   SMALLINT UNSIGNED;
  DECLARE v_used    INT;

  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;

  START TRANSACTION;

  SELECT vehicle_id, start_station_id INTO v_vehicle, v_start
    FROM rides WHERE ride_id = p_ride_id AND status IN ('active','overdue') FOR UPDATE;
  IF v_vehicle IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Ride not found or already returned';
  END IF;

  IF p_station_id <> v_start THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Must return to the station you borrowed from';
  END IF;

  SELECT total_docks INTO v_docks FROM stations WHERE station_id = p_station_id FOR UPDATE;
  SELECT COUNT(*) INTO v_used FROM vehicles WHERE current_station_id = p_station_id;
  IF v_used >= v_docks THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Station is full';
  END IF;

  UPDATE rides
     SET end_time = NOW(), return_station_id = p_station_id,
         battery_end = p_battery_end, status = 'returned'
   WHERE ride_id = p_ride_id;

  UPDATE vehicles
     SET status = 'available', current_station_id = p_station_id,
         battery_level = p_battery_end, battery_updated_at = NOW()
   WHERE vehicle_id = v_vehicle;

  COMMIT;
END$$

DELIMITER ;

-- --------------------------------------------------------

--
-- Table structure for table `app_feedback`
--

DROP TABLE IF EXISTS `app_feedback`;
CREATE TABLE `app_feedback` (
  `feedback_id` int(10) UNSIGNED NOT NULL,
  `user_id` int(10) UNSIGNED NOT NULL,
  `topic` enum('app_bug','payment','account','suggestion','other') NOT NULL,
  `message` text NOT NULL,
  `status` enum('open','read','resolved') NOT NULL DEFAULT 'open',
  `created_at` datetime NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `app_feedback`
--

INSERT INTO `app_feedback` (`feedback_id`, `user_id`, `topic`, `message`, `status`, `created_at`) VALUES
(1, 3, 'payment', 'I paid by QR but my credit took a long time to show up.', 'open', '2026-11-10 15:29:44'),
(2, 1, 'suggestion', 'Could you add a station near the library?', 'read', '2026-11-07 18:20:00');

-- --------------------------------------------------------

--
-- Table structure for table `credit_transactions`
--

DROP TABLE IF EXISTS `credit_transactions`;
CREATE TABLE `credit_transactions` (
  `txn_id` bigint(20) UNSIGNED NOT NULL,
  `user_id` int(10) UNSIGNED NOT NULL,
  `txn_type` enum('topup','ride_payment','refund','adjustment') NOT NULL,
  `amount` decimal(10,2) NOT NULL,
  `balance_after` decimal(10,2) NOT NULL,
  `ride_id` bigint(20) UNSIGNED DEFAULT NULL,
  `topup_id` int(10) UNSIGNED DEFAULT NULL,
  `note` varchar(255) DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `credit_transactions`
--

INSERT INTO `credit_transactions` (`txn_id`, `user_id`, `txn_type`, `amount`, `balance_after`, `ride_id`, `topup_id`, `note`, `created_at`) VALUES
(1, 1, 'topup', 100.00, 100.00, NULL, 1, 'Top up', '2026-10-28 10:00:30'),
(2, 1, 'ride_payment', -100.00, 0.00, 1, NULL, 'Ride EB-004', '2026-10-29 08:05:00'),
(3, 1, 'topup', 250.00, 250.00, NULL, 2, 'Top up', '2026-11-01 10:30:30'),
(4, 1, 'ride_payment', -100.00, 150.00, 2, NULL, 'Ride ES-027', '2026-11-03 13:10:00'),
(5, 1, 'topup', 200.00, 350.00, NULL, 3, 'Top up', '2026-11-04 20:05:30'),
(6, 1, 'ride_payment', -100.00, 250.00, 3, NULL, 'Ride EB-012', '2026-11-05 09:42:00'),
(7, 1, 'ride_payment', -100.00, 150.00, 4, NULL, 'Ride payment', '2026-11-08 01:20:28'),
(8, 4, 'topup', 250.00, 250.00, NULL, 4, 'Top up', '2026-11-02 09:00:40'),
(9, 4, 'ride_payment', -100.00, 150.00, 5, NULL, 'Ride ES-027', '2026-11-10 17:49:44'),
(10, 3, 'ride_payment', -100.00, 40.00, 6, NULL, 'Ride EB-004', '2026-11-09 16:29:44');

-- --------------------------------------------------------

--
-- Table structure for table `problem_reports`
--

DROP TABLE IF EXISTS `problem_reports`;
CREATE TABLE `problem_reports` (
  `report_id` int(10) UNSIGNED NOT NULL,
  `user_id` int(10) UNSIGNED NOT NULL,
  `vehicle_id` int(10) UNSIGNED NOT NULL,
  `ride_id` bigint(20) UNSIGNED DEFAULT NULL,
  `category` enum('brakes_wheels','damaged_part','low_battery','electrical','accident','other') NOT NULL,
  `is_urgent` tinyint(1) NOT NULL DEFAULT 0,
  `location` varchar(150) DEFAULT NULL,
  `details` text DEFAULT NULL,
  `status` enum('open','in_progress','resolved') NOT NULL DEFAULT 'open',
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `resolved_at` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `problem_reports`
--

INSERT INTO `problem_reports` (`report_id`, `user_id`, `vehicle_id`, `ride_id`, `category`, `is_urgent`, `location`, `details`, `status`, `created_at`, `resolved_at`) VALUES
(1, 1, 3, NULL, 'low_battery', 0, NULL, 'Battery drains very quickly', 'open', '2026-11-08 01:13:18', NULL),
(2, 4, 6, 5, 'brakes_wheels', 1, 'in front of Building 2, near the canteen', 'Flat tyre', 'open', '2026-11-10 18:23:44', NULL);

-- --------------------------------------------------------

--
-- Table structure for table `rental_plans`
--

DROP TABLE IF EXISTS `rental_plans`;
CREATE TABLE `rental_plans` (
  `plan_id` tinyint(3) UNSIGNED NOT NULL,
  `name` varchar(50) NOT NULL,
  `duration_hours` smallint(5) UNSIGNED NOT NULL,
  `price` decimal(10,2) NOT NULL,
  `is_active` tinyint(1) NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `rental_plans`
--

INSERT INTO `rental_plans` (`plan_id`, `name`, `duration_hours`, `price`, `is_active`) VALUES
(1, '1 day (24 hrs)', 24, 100.00, 1);

-- --------------------------------------------------------

--
-- Table structure for table `rides`
--

DROP TABLE IF EXISTS `rides`;
CREATE TABLE `rides` (
  `ride_id` bigint(20) UNSIGNED NOT NULL,
  `user_id` int(10) UNSIGNED NOT NULL,
  `vehicle_id` int(10) UNSIGNED NOT NULL,
  `plan_id` tinyint(3) UNSIGNED NOT NULL,
  `start_station_id` int(10) UNSIGNED NOT NULL,
  `return_station_id` int(10) UNSIGNED DEFAULT NULL,
  `start_time` datetime NOT NULL,
  `due_time` datetime NOT NULL,
  `end_time` datetime DEFAULT NULL,
  `battery_start` tinyint(3) UNSIGNED NOT NULL,
  `battery_end` tinyint(3) UNSIGNED DEFAULT NULL,
  `price_paid` decimal(10,2) NOT NULL,
  `status` enum('active','returned','overdue') NOT NULL DEFAULT 'active'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `rides`
--

INSERT INTO `rides` (`ride_id`, `user_id`, `vehicle_id`, `plan_id`, `start_station_id`, `return_station_id`, `start_time`, `due_time`, `end_time`, `battery_start`, `battery_end`, `price_paid`, `status`) VALUES
(1, 1, 8, 1, 3, 3, '2026-10-29 08:05:00', '2026-10-30 08:05:00', '2026-10-29 08:41:00', 90, 77, 100.00, 'returned'),
(2, 1, 6, 1, 2, 2, '2026-11-03 13:10:00', '2026-11-04 13:10:00', '2026-11-03 14:02:00', 70, 54, 100.00, 'returned'),
(3, 1, 1, 1, 1, 1, '2026-11-05 09:42:00', '2026-11-06 09:42:00', '2026-11-05 10:05:00', 92, 86, 100.00, 'returned'),
(4, 1, 1, 1, 1, 1, '2026-11-08 01:20:28', '2026-11-09 01:20:28', '2026-11-08 01:22:54', 86, 79, 100.00, 'returned'),
(5, 4, 6, 1, 2, NULL, '2026-11-10 17:49:44', '2026-11-11 17:49:44', NULL, 54, NULL, 100.00, 'active'),
(6, 3, 8, 1, 3, NULL, '2026-11-09 16:29:44', '2026-11-10 16:29:44', NULL, 77, NULL, 100.00, 'overdue');

-- --------------------------------------------------------

--
-- Table structure for table `stations`
--

DROP TABLE IF EXISTS `stations`;
CREATE TABLE `stations` (
  `station_id` int(10) UNSIGNED NOT NULL,
  `name` varchar(50) NOT NULL,
  `total_docks` smallint(5) UNSIGNED NOT NULL,
  `icon_key` varchar(20) NOT NULL DEFAULT 'building',
  `photo_url` varchar(255) DEFAULT NULL,
  `latitude` decimal(9,6) DEFAULT NULL,
  `longitude` decimal(9,6) DEFAULT NULL,
  `is_active` tinyint(1) NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `stations`
--

INSERT INTO `stations` (`station_id`, `name`, `total_docks`, `icon_key`, `photo_url`, `latitude`, `longitude`, `is_active`) VALUES
(1, 'Building 1', 10, 'building', NULL, NULL, NULL, 1),
(2, 'Building 2', 12, 'building', NULL, NULL, NULL, 1),
(3, 'Building 3', 10, 'building', NULL, NULL, NULL, 1);

-- --------------------------------------------------------

--
-- Table structure for table `topups`
--

DROP TABLE IF EXISTS `topups`;
CREATE TABLE `topups` (
  `topup_id` int(10) UNSIGNED NOT NULL,
  `user_id` int(10) UNSIGNED NOT NULL,
  `amount` decimal(10,2) NOT NULL,
  `payment_method` varchar(20) NOT NULL DEFAULT 'qr',
  `reference_code` varchar(64) DEFAULT NULL,
  `status` enum('pending','paid','failed','expired') NOT NULL DEFAULT 'pending',
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `paid_at` datetime DEFAULT NULL
) ;

--
-- Dumping data for table `topups`
--

INSERT INTO `topups` (`topup_id`, `user_id`, `amount`, `payment_method`, `reference_code`, `status`, `created_at`, `paid_at`) VALUES
(1, 1, 100.00, 'qr', NULL, 'paid', '2026-10-28 10:00:00', '2026-10-28 10:00:30'),
(2, 1, 250.00, 'qr', NULL, 'paid', '2026-11-01 10:30:00', '2026-11-01 10:30:30'),
(3, 1, 200.00, 'qr', NULL, 'paid', '2026-11-04 20:05:00', '2026-11-04 20:05:30'),
(4, 4, 250.00, 'qr', NULL, 'paid', '2026-11-02 09:00:00', '2026-11-02 09:00:40'),
(5, 3, 200.00, 'qr', NULL, 'pending', '2026-11-10 18:17:44', NULL);

-- --------------------------------------------------------

--
-- Table structure for table `users`
--

DROP TABLE IF EXISTS `users`;
CREATE TABLE `users` (
  `user_id` int(10) UNSIGNED NOT NULL,
  `student_id` varchar(20) NOT NULL,
  `username` varchar(50) NOT NULL,
  `full_name` varchar(100) NOT NULL,
  `avatar_id` tinyint(3) UNSIGNED DEFAULT NULL,
  `avatar_url` varchar(255) DEFAULT NULL,
  `password_hash` varchar(255) NOT NULL,
  `role` enum('student','admin') NOT NULL DEFAULT 'student',
  `credit_balance` decimal(10,2) NOT NULL DEFAULT 0.00,
  `is_active` tinyint(1) NOT NULL DEFAULT 1,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `updated_at` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ;

--
-- Dumping data for table `users`
--

INSERT INTO `users` (`user_id`, `student_id`, `username`, `full_name`, `avatar_id`, `avatar_url`, `password_hash`, `role`, `credit_balance`, `is_active`, `created_at`, `updated_at`) VALUES
(1, '6731501118', 'somchai.j', 'Somchai Jaidee', NULL, NULL, '$2b$10$PiZNx9PQlVBrBbmB0TiYKOlN6aPT9Quuqrn77DMJZyUGNr1LLgPY.', 'student', 150.00, 1, '2026-11-08 01:13:18', '2026-11-10 18:29:44'),
(2, 'ADMIN0001', 'admin', 'EcoRide Admin', NULL, NULL, '$2b$10$PiZNx9PQlVBrBbmB0TiYKOlN6aPT9Quuqrn77DMJZyUGNr1LLgPY.', 'admin', 0.00, 1, '2026-11-08 01:13:18', '2026-11-10 18:29:44'),
(3, '6731502229', 'malee.r', 'Malee Ratanachai', NULL, NULL, '$2b$10$PiZNx9PQlVBrBbmB0TiYKOlN6aPT9Quuqrn77DMJZyUGNr1LLgPY.', 'student', 40.00, 1, '2026-11-10 18:29:44', '2026-11-10 18:29:44'),
(4, '6731501086', 'krittin.w', 'Krittin Wong', NULL, NULL, '$2b$10$PiZNx9PQlVBrBbmB0TiYKOlN6aPT9Quuqrn77DMJZyUGNr1LLgPY.', 'student', 150.00, 1, '2026-11-10 18:29:44', '2026-11-10 18:29:44');

-- --------------------------------------------------------

--
-- Table structure for table `vehicles`
--

DROP TABLE IF EXISTS `vehicles`;
CREATE TABLE `vehicles` (
  `vehicle_id` int(10) UNSIGNED NOT NULL,
  `vehicle_code` varchar(10) NOT NULL,
  `type_id` tinyint(3) UNSIGNED NOT NULL,
  `current_station_id` int(10) UNSIGNED DEFAULT NULL,
  `battery_level` tinyint(3) UNSIGNED NOT NULL DEFAULT 100,
  `battery_updated_at` datetime NOT NULL DEFAULT current_timestamp(),
  `status` enum('available','in_use','maintenance') NOT NULL DEFAULT 'available',
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `updated_at` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `vehicles`
--

INSERT INTO `vehicles` (`vehicle_id`, `vehicle_code`, `type_id`, `current_station_id`, `battery_level`, `battery_updated_at`, `status`, `created_at`, `updated_at`) VALUES
(1, 'EB-012', 1, 1, 79, '2026-11-10 18:29:44', 'available', '2026-11-08 01:13:18', '2026-11-08 01:22:54'),
(2, 'EB-015', 1, 1, 72, '2026-11-10 18:29:44', 'available', '2026-11-08 01:13:18', '2026-11-08 01:13:18'),
(3, 'ES-031', 2, 1, 12, '2026-11-10 18:29:44', 'available', '2026-11-08 01:13:18', '2026-11-08 01:13:18'),
(4, 'ES-016', 2, 1, 91, '2026-11-10 18:29:44', 'available', '2026-11-08 01:13:18', '2026-11-08 01:13:18'),
(5, 'EB-021', 1, 2, 95, '2026-11-10 18:29:44', 'available', '2026-11-08 01:13:18', '2026-11-08 01:13:18'),
(6, 'ES-027', 2, NULL, 54, '2026-11-10 18:29:44', 'in_use', '2026-11-08 01:13:18', '2026-11-10 18:29:44'),
(7, 'ES-022', 2, 2, 80, '2026-11-10 18:29:44', 'available', '2026-11-08 01:13:18', '2026-11-08 01:13:18'),
(8, 'EB-004', 1, NULL, 77, '2026-11-10 18:29:44', 'in_use', '2026-11-08 01:13:18', '2026-11-10 18:29:44'),
(9, 'EB-005', 1, 3, 88, '2026-11-10 18:29:44', 'available', '2026-11-08 01:13:18', '2026-11-08 01:13:18'),
(10, 'ES-041', 2, 3, 60, '2026-11-10 18:29:44', 'available', '2026-11-08 01:13:18', '2026-11-08 01:13:18');

-- --------------------------------------------------------

--
-- Table structure for table `vehicle_types`
--

DROP TABLE IF EXISTS `vehicle_types`;
CREATE TABLE `vehicle_types` (
  `type_id` tinyint(3) UNSIGNED NOT NULL,
  `code_prefix` char(2) NOT NULL,
  `name` varchar(50) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `vehicle_types`
--

INSERT INTO `vehicle_types` (`type_id`, `code_prefix`, `name`) VALUES
(1, 'EB', 'Electric bicycle'),
(2, 'ES', 'Electric scooter');

-- --------------------------------------------------------

--
-- Stand-in structure for view `v_ride_history`
-- (See below for the actual view)
--
DROP VIEW IF EXISTS `v_ride_history`;
CREATE TABLE `v_ride_history` (
`ride_id` bigint(20) unsigned
,`user_id` int(10) unsigned
,`vehicle_code` varchar(10)
,`vehicle_type` varchar(50)
,`status` enum('active','returned','overdue')
,`from_station` varchar(50)
,`return_station` varchar(50)
,`start_time` datetime
,`due_time` datetime
,`end_time` datetime
,`duration_min` bigint(21)
,`price_paid` decimal(10,2)
);

-- --------------------------------------------------------

--
-- Stand-in structure for view `v_station_availability`
-- (See below for the actual view)
--
DROP VIEW IF EXISTS `v_station_availability`;
CREATE TABLE `v_station_availability` (
`station_id` int(10) unsigned
,`name` varchar(50)
,`icon_key` varchar(20)
,`photo_url` varchar(255)
,`total_docks` smallint(5) unsigned
,`is_active` tinyint(1)
,`vehicles_docked` bigint(21)
,`free_docks` bigint(21) unsigned
,`bikes` decimal(23,0)
,`scooters` decimal(23,0)
,`ready_to_ride` decimal(23,0)
,`is_full` int(1)
);

-- --------------------------------------------------------

--
-- Stand-in structure for view `v_user_monthly_stats`
-- (See below for the actual view)
--
DROP VIEW IF EXISTS `v_user_monthly_stats`;
CREATE TABLE `v_user_monthly_stats` (
`user_id` int(10) unsigned
,`rides_this_month` bigint(21)
,`hours_total` decimal(44,1)
,`spent_this_month` decimal(32,2)
);

-- --------------------------------------------------------

--
-- Structure for view `v_ride_history`
--
DROP TABLE IF EXISTS `v_ride_history`;

DROP VIEW IF EXISTS `v_ride_history`;
CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `v_ride_history`  AS SELECT `r`.`ride_id` AS `ride_id`, `r`.`user_id` AS `user_id`, `v`.`vehicle_code` AS `vehicle_code`, `vt`.`name` AS `vehicle_type`, `r`.`status` AS `status`, `ss`.`name` AS `from_station`, `rs`.`name` AS `return_station`, `r`.`start_time` AS `start_time`, `r`.`due_time` AS `due_time`, `r`.`end_time` AS `end_time`, timestampdiff(MINUTE,`r`.`start_time`,`r`.`end_time`) AS `duration_min`, `r`.`price_paid` AS `price_paid` FROM ((((`rides` `r` join `vehicles` `v` on(`v`.`vehicle_id` = `r`.`vehicle_id`)) join `vehicle_types` `vt` on(`vt`.`type_id` = `v`.`type_id`)) join `stations` `ss` on(`ss`.`station_id` = `r`.`start_station_id`)) left join `stations` `rs` on(`rs`.`station_id` = `r`.`return_station_id`)) ;

-- --------------------------------------------------------

--
-- Structure for view `v_station_availability`
--
DROP TABLE IF EXISTS `v_station_availability`;

DROP VIEW IF EXISTS `v_station_availability`;
CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `v_station_availability`  AS SELECT `s`.`station_id` AS `station_id`, `s`.`name` AS `name`, `s`.`icon_key` AS `icon_key`, `s`.`photo_url` AS `photo_url`, `s`.`total_docks` AS `total_docks`, `s`.`is_active` AS `is_active`, count(`v`.`vehicle_id`) AS `vehicles_docked`, `s`.`total_docks`- count(`v`.`vehicle_id`) AS `free_docks`, coalesce(sum(`v`.`type_id` = 1),0) AS `bikes`, coalesce(sum(`v`.`type_id` = 2),0) AS `scooters`, coalesce(sum(`v`.`status` = 'available' and `v`.`battery_level` >= 20),0) AS `ready_to_ride`, `s`.`total_docks`- count(`v`.`vehicle_id`) = 0 AS `is_full` FROM (`stations` `s` left join `vehicles` `v` on(`v`.`current_station_id` = `s`.`station_id`)) GROUP BY `s`.`station_id`, `s`.`name`, `s`.`icon_key`, `s`.`photo_url`, `s`.`total_docks`, `s`.`is_active` ;

-- --------------------------------------------------------

--
-- Structure for view `v_user_monthly_stats`
--
DROP TABLE IF EXISTS `v_user_monthly_stats`;

DROP VIEW IF EXISTS `v_user_monthly_stats`;
CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `v_user_monthly_stats`  AS SELECT `u`.`user_id` AS `user_id`, count(`r`.`ride_id`) AS `rides_this_month`, round(coalesce(sum(timestampdiff(MINUTE,`r`.`start_time`,coalesce(`r`.`end_time`,current_timestamp()))),0) / 60,1) AS `hours_total`, coalesce(sum(`r`.`price_paid`),0) AS `spent_this_month` FROM (`users` `u` left join `rides` `r` on(`r`.`user_id` = `u`.`user_id` and `r`.`start_time` >= date_format(curdate(),'%Y-%m-01'))) GROUP BY `u`.`user_id` ;

--
-- Indexes for dumped tables
--

--
-- Indexes for table `app_feedback`
--
ALTER TABLE `app_feedback`
  ADD PRIMARY KEY (`feedback_id`),
  ADD KEY `idx_feedback_status` (`status`,`created_at`),
  ADD KEY `fk_feedback_user` (`user_id`);

--
-- Indexes for table `credit_transactions`
--
ALTER TABLE `credit_transactions`
  ADD PRIMARY KEY (`txn_id`),
  ADD KEY `idx_txn_user_time` (`user_id`,`created_at`),
  ADD KEY `fk_txn_ride` (`ride_id`),
  ADD KEY `fk_txn_topup` (`topup_id`);

--
-- Indexes for table `problem_reports`
--
ALTER TABLE `problem_reports`
  ADD PRIMARY KEY (`report_id`),
  ADD KEY `idx_reports_status` (`status`,`created_at`),
  ADD KEY `idx_reports_vehicle` (`vehicle_id`),
  ADD KEY `fk_reports_user` (`user_id`),
  ADD KEY `fk_reports_ride` (`ride_id`),
  ADD KEY `idx_reports_urgent` (`is_urgent`,`status`,`created_at`);

--
-- Indexes for table `rental_plans`
--
ALTER TABLE `rental_plans`
  ADD PRIMARY KEY (`plan_id`);

--
-- Indexes for table `rides`
--
ALTER TABLE `rides`
  ADD PRIMARY KEY (`ride_id`),
  ADD KEY `idx_rides_user_time` (`user_id`,`start_time`),
  ADD KEY `idx_rides_vehicle` (`vehicle_id`,`start_time`),
  ADD KEY `idx_rides_status_due` (`status`,`due_time`),
  ADD KEY `fk_rides_plan` (`plan_id`),
  ADD KEY `fk_rides_start_st` (`start_station_id`),
  ADD KEY `fk_rides_ret_st` (`return_station_id`);

--
-- Indexes for table `stations`
--
ALTER TABLE `stations`
  ADD PRIMARY KEY (`station_id`),
  ADD UNIQUE KEY `uq_stations_name` (`name`);

--
-- Indexes for table `topups`
--
ALTER TABLE `topups`
  ADD PRIMARY KEY (`topup_id`),
  ADD UNIQUE KEY `uq_topups_reference` (`reference_code`),
  ADD KEY `idx_topups_user` (`user_id`,`created_at`);

--
-- Indexes for table `users`
--
ALTER TABLE `users`
  ADD PRIMARY KEY (`user_id`),
  ADD UNIQUE KEY `uq_users_student_id` (`student_id`),
  ADD UNIQUE KEY `uq_users_username` (`username`);

--
-- Indexes for table `vehicles`
--
ALTER TABLE `vehicles`
  ADD PRIMARY KEY (`vehicle_id`),
  ADD UNIQUE KEY `uq_vehicles_code` (`vehicle_code`),
  ADD KEY `idx_vehicles_station_status` (`current_station_id`,`status`),
  ADD KEY `fk_vehicles_type` (`type_id`);

--
-- Indexes for table `vehicle_types`
--
ALTER TABLE `vehicle_types`
  ADD PRIMARY KEY (`type_id`),
  ADD UNIQUE KEY `uq_vehicle_types_prefix` (`code_prefix`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `app_feedback`
--
ALTER TABLE `app_feedback`
  MODIFY `feedback_id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- AUTO_INCREMENT for table `credit_transactions`
--
ALTER TABLE `credit_transactions`
  MODIFY `txn_id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=11;

--
-- AUTO_INCREMENT for table `problem_reports`
--
ALTER TABLE `problem_reports`
  MODIFY `report_id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- AUTO_INCREMENT for table `rental_plans`
--
ALTER TABLE `rental_plans`
  MODIFY `plan_id` tinyint(3) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT for table `rides`
--
ALTER TABLE `rides`
  MODIFY `ride_id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=7;

--
-- AUTO_INCREMENT for table `stations`
--
ALTER TABLE `stations`
  MODIFY `station_id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

--
-- AUTO_INCREMENT for table `topups`
--
ALTER TABLE `topups`
  MODIFY `topup_id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `users`
--
ALTER TABLE `users`
  MODIFY `user_id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `vehicles`
--
ALTER TABLE `vehicles`
  MODIFY `vehicle_id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=11;

--
-- AUTO_INCREMENT for table `vehicle_types`
--
ALTER TABLE `vehicle_types`
  MODIFY `type_id` tinyint(3) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- Constraints for dumped tables
--

--
-- Constraints for table `app_feedback`
--
ALTER TABLE `app_feedback`
  ADD CONSTRAINT `fk_feedback_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`);

--
-- Constraints for table `credit_transactions`
--
ALTER TABLE `credit_transactions`
  ADD CONSTRAINT `fk_txn_ride` FOREIGN KEY (`ride_id`) REFERENCES `rides` (`ride_id`),
  ADD CONSTRAINT `fk_txn_topup` FOREIGN KEY (`topup_id`) REFERENCES `topups` (`topup_id`),
  ADD CONSTRAINT `fk_txn_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`);

--
-- Constraints for table `problem_reports`
--
ALTER TABLE `problem_reports`
  ADD CONSTRAINT `fk_reports_ride` FOREIGN KEY (`ride_id`) REFERENCES `rides` (`ride_id`),
  ADD CONSTRAINT `fk_reports_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`),
  ADD CONSTRAINT `fk_reports_vehicle` FOREIGN KEY (`vehicle_id`) REFERENCES `vehicles` (`vehicle_id`);

--
-- Constraints for table `rides`
--
ALTER TABLE `rides`
  ADD CONSTRAINT `fk_rides_plan` FOREIGN KEY (`plan_id`) REFERENCES `rental_plans` (`plan_id`),
  ADD CONSTRAINT `fk_rides_ret_st` FOREIGN KEY (`return_station_id`) REFERENCES `stations` (`station_id`),
  ADD CONSTRAINT `fk_rides_start_st` FOREIGN KEY (`start_station_id`) REFERENCES `stations` (`station_id`),
  ADD CONSTRAINT `fk_rides_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`),
  ADD CONSTRAINT `fk_rides_vehicle` FOREIGN KEY (`vehicle_id`) REFERENCES `vehicles` (`vehicle_id`);

--
-- Constraints for table `topups`
--
ALTER TABLE `topups`
  ADD CONSTRAINT `fk_topups_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`);

--
-- Constraints for table `vehicles`
--
ALTER TABLE `vehicles`
  ADD CONSTRAINT `fk_vehicles_station` FOREIGN KEY (`current_station_id`) REFERENCES `stations` (`station_id`),
  ADD CONSTRAINT `fk_vehicles_type` FOREIGN KEY (`type_id`) REFERENCES `vehicle_types` (`type_id`);

DELIMITER $$
--
-- Events
--
DROP EVENT IF EXISTS `ev_mark_overdue`$$
CREATE DEFINER=`root`@`localhost` EVENT `ev_mark_overdue` ON SCHEDULE EVERY 5 MINUTE STARTS '2026-11-10 18:29:44' ON COMPLETION NOT PRESERVE ENABLE DO CALL sp_mark_overdue()$$

DELIMITER ;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
