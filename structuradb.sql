-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Host: 127.0.0.1
-- Generation Time: Nov 20, 2025 at 02:13 PM
-- Server version: 11.4.5-MariaDB
-- PHP Version: 8.0.30

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `structuradb`
--

-- --------------------------------------------------------

--
-- Table structure for table `attendance`
--

CREATE TABLE `attendance` (
  `attendance_id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `project_id` int(11) NOT NULL,
  `date` date NOT NULL,
  `time_in` time DEFAULT NULL,
  `time_out` time DEFAULT NULL,
  `hours_worked` decimal(5,2) DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `expenses`
--

CREATE TABLE `expenses` (
  `expense_id` int(11) NOT NULL,
  `project_id` int(11) NOT NULL,
  `category_id` int(11) NOT NULL,
  `amount` decimal(12,2) NOT NULL,
  `description` text DEFAULT NULL,
  `date` date NOT NULL,
  `created_at` timestamp NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `expense_categories`
--

CREATE TABLE `expense_categories` (
  `category_id` int(11) NOT NULL,
  `category_name` varchar(100) NOT NULL,
  `description` text DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `inventory`
--

CREATE TABLE `inventory` (
  `inventory_id` int(11) NOT NULL,
  `project_id` int(11) NOT NULL,
  `material_id` int(11) NOT NULL,
  `quantity_available` decimal(10,2) NOT NULL DEFAULT 0.00,
  `minimum_stock` decimal(10,2) DEFAULT 0.00,
  `last_restocked` date DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Stand-in structure for view `low_stock_alerts`
-- (See below for the actual view)
--
CREATE TABLE `low_stock_alerts` (
`inventory_id` int(11)
,`project_name` varchar(150)
,`material_name` varchar(100)
,`quantity_available` decimal(10,2)
,`minimum_stock` decimal(10,2)
,`deficit` decimal(11,2)
);

-- --------------------------------------------------------

--
-- Table structure for table `materials`
--

CREATE TABLE `materials` (
  `material_id` int(11) NOT NULL,
  `material_name` varchar(100) NOT NULL,
  `description` text DEFAULT NULL,
  `unit` varchar(20) DEFAULT NULL,
  `unit_price` decimal(10,2) DEFAULT NULL,
  `supplier_info` text DEFAULT NULL,
  `is_active` tinyint(1) DEFAULT 1,
  `created_at` timestamp NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Stand-in structure for view `nearby_workers_query`
-- (See below for the actual view)
--
CREATE TABLE `nearby_workers_query` (
`user_id` int(11)
,`full_name` varchar(201)
,`address` text
,`phone` varchar(20)
,`latitude` decimal(10,8)
,`longitude` decimal(11,8)
,`distance_km` double
);

-- --------------------------------------------------------

--
-- Table structure for table `progress_logs`
--

CREATE TABLE `progress_logs` (
  `log_id` int(11) NOT NULL,
  `project_id` int(11) NOT NULL,
  `supervisor_id` int(11) NOT NULL,
  `log_date` date NOT NULL,
  `description` text NOT NULL,
  `photo_url` varchar(255) DEFAULT NULL,
  `progress_percentage` decimal(5,2) DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `projects`
--

CREATE TABLE `projects` (
  `project_id` int(11) NOT NULL,
  `client_id` int(11) NOT NULL,
  `project_name` varchar(150) NOT NULL,
  `location` varchar(255) DEFAULT NULL,
  `start_date` date DEFAULT NULL,
  `end_date` date DEFAULT NULL,
  `budget` decimal(15,2) DEFAULT NULL,
  `actual_cost` decimal(15,2) DEFAULT 0.00,
  `status` enum('Planned','Ongoing','Completed','On-Hold','Cancelled') DEFAULT 'Planned',
  `priority` enum('Low','Medium','High','Critical') DEFAULT 'Medium',
  `created_at` timestamp NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Stand-in structure for view `project_financial_summary`
-- (See below for the actual view)
--
CREATE TABLE `project_financial_summary` (
`project_id` int(11)
,`project_name` varchar(150)
,`budget` decimal(15,2)
,`actual_cost` decimal(15,2)
,`remaining_budget` decimal(16,2)
,`total_expenses` decimal(34,2)
,`total_tasks` bigint(21)
,`completed_tasks` bigint(21)
);

-- --------------------------------------------------------

--
-- Stand-in structure for view `project_progress_summary`
-- (See below for the actual view)
--
CREATE TABLE `project_progress_summary` (
`project_id` int(11)
,`project_name` varchar(150)
,`status` enum('Planned','Ongoing','Completed','On-Hold','Cancelled')
,`start_date` date
,`end_date` date
,`total_tasks` bigint(21)
,`completed_tasks` bigint(21)
,`avg_progress` decimal(9,6)
,`total_expenses` decimal(34,2)
,`budget` decimal(15,2)
);

-- --------------------------------------------------------

--
-- Table structure for table `roles`
--

CREATE TABLE `roles` (
  `role_id` int(11) NOT NULL,
  `role_name` varchar(50) NOT NULL,
  `description` text DEFAULT NULL,
  `permissions` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`permissions`)),
  `created_at` timestamp NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `roles`
--

INSERT INTO `roles` (`role_id`, `role_name`, `description`, `permissions`, `created_at`) VALUES
(1, 'Super Admin', 'Full system access', '[\"*\"]', '2025-11-20 13:08:51'),
(2, 'Contractor Admin', 'Contractor management', '[\"projects.*\", \"users.*\", \"reports.*\"]', '2025-11-20 13:08:51'),
(3, 'Project Manager', 'Project management', '[\"projects.read\", \"projects.update\", \"tasks.*\", \"attendance.*\"]', '2025-11-20 13:08:51'),
(4, 'Architect', 'Design and planning', '[\"projects.read\", \"design.*\", \"materials.read\"]', '2025-11-20 13:08:51'),
(5, 'Engineer', 'Engineering oversight', '[\"projects.read\", \"progress.*\", \"quality.*\"]', '2025-11-20 13:08:51'),
(6, 'Supervisor', 'Site supervision', '[\"attendance.*\", \"progress.*\", \"inventory.read\"]', '2025-11-20 13:08:51'),
(7, 'Foreman', 'Team leadership', '[\"attendance.update\", \"tasks.update\", \"workers.*\"]', '2025-11-20 13:08:51'),
(8, 'Worker', 'Construction worker', '[\"attendance.self\", \"tasks.own\"]', '2025-11-20 13:08:51'),
(9, 'Client', 'Project client', '[\"projects.own\", \"progress.read\"]', '2025-11-20 13:08:51');

-- --------------------------------------------------------

--
-- Table structure for table `tasks`
--

CREATE TABLE `tasks` (
  `task_id` int(11) NOT NULL,
  `project_id` int(11) NOT NULL,
  `parent_task_id` int(11) DEFAULT NULL,
  `task_name` varchar(150) NOT NULL,
  `description` text DEFAULT NULL,
  `planned_start` date DEFAULT NULL,
  `planned_end` date DEFAULT NULL,
  `actual_start` date DEFAULT NULL,
  `actual_end` date DEFAULT NULL,
  `estimated_hours` decimal(6,2) DEFAULT 0.00,
  `actual_hours` decimal(6,2) DEFAULT 0.00,
  `status` enum('Not Started','In Progress','Completed','Blocked','Deferred') DEFAULT 'Not Started',
  `priority` enum('Low','Medium','High','Critical') DEFAULT 'Medium',
  `progress_percentage` decimal(5,2) DEFAULT 0.00,
  `dependencies` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`dependencies`)),
  `created_at` timestamp NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `users`
--

CREATE TABLE `users` (
  `user_id` int(11) NOT NULL,
  `email` varchar(100) NOT NULL,
  `password_hash` varchar(255) NOT NULL,
  `first_name` varchar(100) NOT NULL,
  `middle_name` varchar(100) DEFAULT NULL,
  `last_name` varchar(100) NOT NULL,
  `birthdate` date DEFAULT NULL,
  `valid_id` varchar(255) DEFAULT NULL,
  `phone` varchar(20) DEFAULT NULL,
  `address` text DEFAULT NULL,
  `latitude` decimal(10,8) DEFAULT NULL,
  `longitude` decimal(11,8) DEFAULT NULL,
  `is_active` tinyint(1) DEFAULT 1,
  `last_login` timestamp NULL DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `user_roles`
--

CREATE TABLE `user_roles` (
  `user_id` int(11) NOT NULL,
  `role_id` int(11) NOT NULL,
  `assigned_at` timestamp NULL DEFAULT current_timestamp(),
  `assigned_by` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Stand-in structure for view `worker_attendance_summary`
-- (See below for the actual view)
--
CREATE TABLE `worker_attendance_summary` (
`user_id` int(11)
,`full_name` varchar(201)
,`date` date
,`hours_worked` decimal(5,2)
,`project_name` varchar(150)
);

-- --------------------------------------------------------

--
-- Stand-in structure for view `worker_locations`
-- (See below for the actual view)
--
CREATE TABLE `worker_locations` (
`user_id` int(11)
,`full_name` varchar(201)
,`role_name` varchar(50)
,`address` text
,`latitude` decimal(10,8)
,`longitude` decimal(11,8)
,`phone` varchar(20)
,`is_active` tinyint(1)
);

-- --------------------------------------------------------

--
-- Table structure for table `workforce_schedule`
--

CREATE TABLE `workforce_schedule` (
  `schedule_id` int(11) NOT NULL,
  `task_id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `scheduled_date` date NOT NULL,
  `planned_hours` decimal(5,2) NOT NULL,
  `actual_hours` decimal(5,2) DEFAULT NULL,
  `status` enum('Scheduled','In Progress','Completed','Absent') DEFAULT 'Scheduled',
  `created_at` timestamp NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Structure for view `low_stock_alerts`
--
DROP TABLE IF EXISTS `low_stock_alerts`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `low_stock_alerts`  AS SELECT `i`.`inventory_id` AS `inventory_id`, `p`.`project_name` AS `project_name`, `m`.`material_name` AS `material_name`, `i`.`quantity_available` AS `quantity_available`, `i`.`minimum_stock` AS `minimum_stock`, `i`.`quantity_available`- `i`.`minimum_stock` AS `deficit` FROM ((`inventory` `i` join `projects` `p` on(`i`.`project_id` = `p`.`project_id`)) join `materials` `m` on(`i`.`material_id` = `m`.`material_id`)) WHERE `i`.`quantity_available` <= `i`.`minimum_stock` ORDER BY `i`.`quantity_available`- `i`.`minimum_stock` ASC ;

-- --------------------------------------------------------

--
-- Structure for view `nearby_workers_query`
--
DROP TABLE IF EXISTS `nearby_workers_query`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `nearby_workers_query`  AS SELECT `u`.`user_id` AS `user_id`, concat(`u`.`first_name`,' ',`u`.`last_name`) AS `full_name`, `u`.`address` AS `address`, `u`.`phone` AS `phone`, `u`.`latitude` AS `latitude`, `u`.`longitude` AS `longitude`, 6371 * acos(cos(radians(0)) * cos(radians(`u`.`latitude`)) * cos(radians(`u`.`longitude`) - radians(0)) + sin(radians(0)) * sin(radians(`u`.`latitude`))) AS `distance_km` FROM ((`users` `u` join `user_roles` `ur` on(`u`.`user_id` = `ur`.`user_id`)) join `roles` `r` on(`ur`.`role_id` = `r`.`role_id`)) WHERE `r`.`role_name` = 'Worker' AND `u`.`is_active` = 1 AND `u`.`latitude` is not null AND `u`.`longitude` is not null ;

-- --------------------------------------------------------

--
-- Structure for view `project_financial_summary`
--
DROP TABLE IF EXISTS `project_financial_summary`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `project_financial_summary`  AS SELECT `p`.`project_id` AS `project_id`, `p`.`project_name` AS `project_name`, `p`.`budget` AS `budget`, `p`.`actual_cost` AS `actual_cost`, `p`.`budget`- `p`.`actual_cost` AS `remaining_budget`, coalesce(sum(`e`.`amount`),0) AS `total_expenses`, count(`t`.`task_id`) AS `total_tasks`, count(case when `t`.`status` = 'Completed' then 1 end) AS `completed_tasks` FROM ((`projects` `p` left join `expenses` `e` on(`p`.`project_id` = `e`.`project_id`)) left join `tasks` `t` on(`p`.`project_id` = `t`.`project_id`)) GROUP BY `p`.`project_id`, `p`.`project_name`, `p`.`budget`, `p`.`actual_cost` ;

-- --------------------------------------------------------

--
-- Structure for view `project_progress_summary`
--
DROP TABLE IF EXISTS `project_progress_summary`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `project_progress_summary`  AS SELECT `p`.`project_id` AS `project_id`, `p`.`project_name` AS `project_name`, `p`.`status` AS `status`, `p`.`start_date` AS `start_date`, `p`.`end_date` AS `end_date`, count(`t`.`task_id`) AS `total_tasks`, count(case when `t`.`status` = 'Completed' then 1 end) AS `completed_tasks`, avg(`t`.`progress_percentage`) AS `avg_progress`, sum(`e`.`amount`) AS `total_expenses`, `p`.`budget` AS `budget` FROM ((`projects` `p` left join `tasks` `t` on(`p`.`project_id` = `t`.`project_id`)) left join `expenses` `e` on(`p`.`project_id` = `e`.`project_id`)) GROUP BY `p`.`project_id`, `p`.`project_name`, `p`.`status`, `p`.`start_date`, `p`.`end_date`, `p`.`budget` ;

-- --------------------------------------------------------

--
-- Structure for view `worker_attendance_summary`
--
DROP TABLE IF EXISTS `worker_attendance_summary`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `worker_attendance_summary`  AS SELECT `u`.`user_id` AS `user_id`, concat(`u`.`first_name`,' ',`u`.`last_name`) AS `full_name`, `a`.`date` AS `date`, `a`.`hours_worked` AS `hours_worked`, `p`.`project_name` AS `project_name` FROM ((((`users` `u` join `attendance` `a` on(`u`.`user_id` = `a`.`user_id`)) join `projects` `p` on(`a`.`project_id` = `p`.`project_id`)) join `user_roles` `ur` on(`u`.`user_id` = `ur`.`user_id`)) join `roles` `r` on(`ur`.`role_id` = `r`.`role_id`)) WHERE `r`.`role_name` = 'Worker' ;

-- --------------------------------------------------------

--
-- Structure for view `worker_locations`
--
DROP TABLE IF EXISTS `worker_locations`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `worker_locations`  AS SELECT `u`.`user_id` AS `user_id`, concat(`u`.`first_name`,' ',`u`.`last_name`) AS `full_name`, `r`.`role_name` AS `role_name`, `u`.`address` AS `address`, `u`.`latitude` AS `latitude`, `u`.`longitude` AS `longitude`, `u`.`phone` AS `phone`, `u`.`is_active` AS `is_active` FROM ((`users` `u` join `user_roles` `ur` on(`u`.`user_id` = `ur`.`user_id`)) join `roles` `r` on(`ur`.`role_id` = `r`.`role_id`)) WHERE `r`.`role_name` = 'Worker' AND `u`.`is_active` = 1 ;

--
-- Indexes for dumped tables
--

--
-- Indexes for table `attendance`
--
ALTER TABLE `attendance`
  ADD PRIMARY KEY (`attendance_id`),
  ADD UNIQUE KEY `unique_attendance` (`user_id`,`project_id`,`date`),
  ADD KEY `project_id` (`project_id`),
  ADD KEY `idx_attendance_date` (`date`);

--
-- Indexes for table `expenses`
--
ALTER TABLE `expenses`
  ADD PRIMARY KEY (`expense_id`),
  ADD KEY `project_id` (`project_id`),
  ADD KEY `category_id` (`category_id`),
  ADD KEY `idx_expense_date` (`date`);

--
-- Indexes for table `expense_categories`
--
ALTER TABLE `expense_categories`
  ADD PRIMARY KEY (`category_id`),
  ADD UNIQUE KEY `category_name` (`category_name`);

--
-- Indexes for table `inventory`
--
ALTER TABLE `inventory`
  ADD PRIMARY KEY (`inventory_id`),
  ADD UNIQUE KEY `unique_inventory` (`project_id`,`material_id`),
  ADD KEY `material_id` (`material_id`),
  ADD KEY `idx_low_stock` (`quantity_available`,`minimum_stock`);

--
-- Indexes for table `materials`
--
ALTER TABLE `materials`
  ADD PRIMARY KEY (`material_id`),
  ADD KEY `idx_material_active` (`is_active`);

--
-- Indexes for table `progress_logs`
--
ALTER TABLE `progress_logs`
  ADD PRIMARY KEY (`log_id`),
  ADD KEY `project_id` (`project_id`),
  ADD KEY `supervisor_id` (`supervisor_id`),
  ADD KEY `idx_log_date` (`log_date`);

--
-- Indexes for table `projects`
--
ALTER TABLE `projects`
  ADD PRIMARY KEY (`project_id`),
  ADD KEY `client_id` (`client_id`),
  ADD KEY `idx_project_status` (`status`),
  ADD KEY `idx_project_dates` (`start_date`,`end_date`);

--
-- Indexes for table `roles`
--
ALTER TABLE `roles`
  ADD PRIMARY KEY (`role_id`),
  ADD UNIQUE KEY `role_name` (`role_name`);

--
-- Indexes for table `tasks`
--
ALTER TABLE `tasks`
  ADD PRIMARY KEY (`task_id`),
  ADD KEY `project_id` (`project_id`),
  ADD KEY `parent_task_id` (`parent_task_id`),
  ADD KEY `idx_task_status` (`status`),
  ADD KEY `idx_task_priority` (`priority`),
  ADD KEY `idx_task_dates` (`planned_start`,`planned_end`);

--
-- Indexes for table `users`
--
ALTER TABLE `users`
  ADD PRIMARY KEY (`user_id`),
  ADD UNIQUE KEY `email` (`email`),
  ADD KEY `idx_user_active` (`is_active`),
  ADD KEY `idx_latitude_longitude` (`latitude`,`longitude`);
ALTER TABLE `users` ADD FULLTEXT KEY `idx_user_search` (`first_name`,`last_name`,`email`);

--
-- Indexes for table `user_roles`
--
ALTER TABLE `user_roles`
  ADD PRIMARY KEY (`user_id`,`role_id`),
  ADD KEY `role_id` (`role_id`);

--
-- Indexes for table `workforce_schedule`
--
ALTER TABLE `workforce_schedule`
  ADD PRIMARY KEY (`schedule_id`),
  ADD KEY `task_id` (`task_id`),
  ADD KEY `user_id` (`user_id`),
  ADD KEY `idx_schedule_date` (`scheduled_date`),
  ADD KEY `idx_schedule_status` (`status`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `attendance`
--
ALTER TABLE `attendance`
  MODIFY `attendance_id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `expenses`
--
ALTER TABLE `expenses`
  MODIFY `expense_id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `expense_categories`
--
ALTER TABLE `expense_categories`
  MODIFY `category_id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `inventory`
--
ALTER TABLE `inventory`
  MODIFY `inventory_id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `materials`
--
ALTER TABLE `materials`
  MODIFY `material_id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `progress_logs`
--
ALTER TABLE `progress_logs`
  MODIFY `log_id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `projects`
--
ALTER TABLE `projects`
  MODIFY `project_id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `roles`
--
ALTER TABLE `roles`
  MODIFY `role_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=10;

--
-- AUTO_INCREMENT for table `tasks`
--
ALTER TABLE `tasks`
  MODIFY `task_id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `users`
--
ALTER TABLE `users`
  MODIFY `user_id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `workforce_schedule`
--
ALTER TABLE `workforce_schedule`
  MODIFY `schedule_id` int(11) NOT NULL AUTO_INCREMENT;

--
-- Constraints for dumped tables
--

--
-- Constraints for table `attendance`
--
ALTER TABLE `attendance`
  ADD CONSTRAINT `attendance_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE,
  ADD CONSTRAINT `attendance_ibfk_2` FOREIGN KEY (`project_id`) REFERENCES `projects` (`project_id`) ON DELETE CASCADE;

--
-- Constraints for table `expenses`
--
ALTER TABLE `expenses`
  ADD CONSTRAINT `expenses_ibfk_1` FOREIGN KEY (`project_id`) REFERENCES `projects` (`project_id`) ON DELETE CASCADE,
  ADD CONSTRAINT `expenses_ibfk_2` FOREIGN KEY (`category_id`) REFERENCES `expense_categories` (`category_id`);

--
-- Constraints for table `inventory`
--
ALTER TABLE `inventory`
  ADD CONSTRAINT `inventory_ibfk_1` FOREIGN KEY (`project_id`) REFERENCES `projects` (`project_id`) ON DELETE CASCADE,
  ADD CONSTRAINT `inventory_ibfk_2` FOREIGN KEY (`material_id`) REFERENCES `materials` (`material_id`);

--
-- Constraints for table `progress_logs`
--
ALTER TABLE `progress_logs`
  ADD CONSTRAINT `progress_logs_ibfk_1` FOREIGN KEY (`project_id`) REFERENCES `projects` (`project_id`) ON DELETE CASCADE,
  ADD CONSTRAINT `progress_logs_ibfk_2` FOREIGN KEY (`supervisor_id`) REFERENCES `users` (`user_id`);

--
-- Constraints for table `projects`
--
ALTER TABLE `projects`
  ADD CONSTRAINT `projects_ibfk_1` FOREIGN KEY (`client_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE;

--
-- Constraints for table `tasks`
--
ALTER TABLE `tasks`
  ADD CONSTRAINT `tasks_ibfk_1` FOREIGN KEY (`project_id`) REFERENCES `projects` (`project_id`) ON DELETE CASCADE,
  ADD CONSTRAINT `tasks_ibfk_2` FOREIGN KEY (`parent_task_id`) REFERENCES `tasks` (`task_id`) ON DELETE SET NULL;

--
-- Constraints for table `user_roles`
--
ALTER TABLE `user_roles`
  ADD CONSTRAINT `user_roles_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE,
  ADD CONSTRAINT `user_roles_ibfk_2` FOREIGN KEY (`role_id`) REFERENCES `roles` (`role_id`);

--
-- Constraints for table `workforce_schedule`
--
ALTER TABLE `workforce_schedule`
  ADD CONSTRAINT `workforce_schedule_ibfk_1` FOREIGN KEY (`task_id`) REFERENCES `tasks` (`task_id`) ON DELETE CASCADE,
  ADD CONSTRAINT `workforce_schedule_ibfk_2` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
