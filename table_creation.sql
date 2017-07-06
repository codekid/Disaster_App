-- phpMyAdmin SQL Dump
-- version 4.6.5.2
-- https://www.phpmyadmin.net/
--
-- Host: 127.0.0.1
-- Generation Time: Jul 06, 2017 at 05:29 PM
-- Server version: 10.1.21-MariaDB
-- PHP Version: 7.1.1

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `test`
--

DELIMITER $$
--
-- Procedures
--
CREATE DEFINER=`root`@`localhost` PROCEDURE `check_disaster_dimensions` ()  BEGIN
	INSERT INTO STATE (NAME)
	SELECT DISTINCT IFNULL(STATE, "UNKNOWN")
	FROM ST_STORM_DATA_TEMP
	WHERE IFNULL(STATE, "UNKNOWN") NOT IN (
		SELECT STATE_DESC
		FROM DT_STATE
		);
		
	INSERT INTO DT_STATE_CZ (STATE_ID, CZ_DESC)
	SELECT DISTINCT STATE.ID, IFNULL(CZ_NAME, "UNKNOWN")
	FROM (SELECT DISTINCT STATE, CZ_NAME FROM ST_STORM_DATA_TEMP)TMP
	JOIN STATE
	ON TMP.STATE = STATE.NAME
	WHERE (STATE, CZ_NAME) NOT IN (
		SELECT DISTINCT STATE, CZ_DESC
		FROM DT_STATE_CZ
		);

		
	INSERT INTO DT_MONTHS (MONTH_DESC)
	SELECT DISTINCT MONTH_NAME
	FROM ST_STORM_DATA_TEMP
	WHERE MONTH_NAME NOT IN (
		SELECT MONTH_DESC
		FROM DT_MONTHS
		);
	
	INSERT INTO DT_DISASTER_TYPES (DISASTER_DESC)
	SELECT DISTINCT IFNULL(EVENT_TYPE, "UNKNOWN")
	FROM ST_STORM_DATA_TEMP
	WHERE IFNULL(EVENT_TYPE, "UNKNOWN") NOT IN (
		SELECT DISASTER_DESC
		FROM DT_DISASTER_TYPES
		);
		
	COMMIT;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `populate_ft` ()  BEGIN
	DECLARE v$BEGIN_DATE VARCHAR(8);
	DECLARE v$END_DATE VARCHAR(8);
	DECLARE v$STATE_ID INT;
	DECLARE v$MONTH_ID INT;
	DECLARE v$DISASTER_ID INT;
	DECLARE v$INJURIES_DIRECT INT;
	DECLARE v$DEATHS_DIRECT INT;
	DECLARE v$INJURIES_INDIRECT INT;
	DECLARE v$DEATHS_INDIRECT INT;
	DECLARE v$DAMAGE_PROPERTY DOUBLE;
	DECLARE v$DAMAGE_CROPS DOUBLE;
	DECLARE v$UNITS_COUNT INT;
	DECLARE done int DEFAULT FALSE;
	DECLARE b_collect  CURSOR FOR
	SELECT 
		TMP.BEGIN_DATE,
		TMP.END_DATE,
		STATE.ID STATE_ID,
		MONTHS.MONTH_ID,
	    DIST.DISASTER_ID,
	    TMP.INJURIES_DIRECT,
	    TMP.DEATHS_DIRECT,
	    TMP.INJURIES_DIRECT,
	    TMP.DEATHS_INDIRECT,
	    TMP.DAMAGE_PROPERTY,
	    TMP.DAMAGE_CROPS,
	    TMP.UNITS_COUNT
	FROM FT_DISASTER_SUMMARY_TEMP TMP
	JOIN STATE
	ON TMP.STATE = STATE.STATE_NAME
	JOIN DT_MONTHS MONTHS
	ON TMP.MONTH_NAME = MONTHS.MONTH_DESC
	JOIN DT_DISASTER_TYPES DIST
	ON TMP.EVENT_TYPE = DIST.DISASTER_DESC;

	DECLARE CONTINUE HANDLER FOR NOT FOUND
		SET DONE := TRUE;

	OPEN b_collect;
	read_label:
	LOOP
		FETCH b_collect INTO
			v$BEGIN_DATE,
			v$END_DATE,
			v$STATE_ID,
			v$MONTH_ID,
			v$DISASTER_ID,
			v$INJURIES_DIRECT,
			v$DEATHS_DIRECT,
			v$INJURIES_INDIRECT,
			v$DEATHS_INDIRECT,
			v$DAMAGE_PROPERTY,
			v$DAMAGE_CROPS,
			v$UNITS_COUNT;
	IF DONE THEN
		LEAVE read_label;
	end if;
	INSERT INTO FT_DISASTER_SUMMARY
    VALUES(
			v$BEGIN_DATE,
			v$END_DATE,
			v$STATE_ID,
			v$MONTH_ID,
			v$DISASTER_ID,
			v$INJURIES_DIRECT,
			v$DEATHS_DIRECT,
			v$INJURIES_INDIRECT,
			v$DEATHS_INDIRECT,
			v$DAMAGE_PROPERTY,
			v$DAMAGE_CROPS,
			v$UNITS_COUNT);
	END LOOP;
	COMMIT;
	CLOSE b_collect;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `process_data` ()  BEGIN
	DECLARE unprocessed_files INT;
	SET unprocessed_files =1;
	
	
	check_if_finished: WHILE unprocessed_files <> 0 DO

    TRUNCATE TABLE LOG_STORM_DATA_PROCESSING;

	SELECT 
		COUNT(*)
		INTO unprocessed_files
	FROM LOG_STORM_DATA_LOADED
	WHERE FILENAME NOT IN 
		(
			SELECT FILENAME FROM LOG_STORM_DATA_PROCESSED
		)
	;

	INSERT INTO LOG_STORM_DATA_PROCESSING
	SELECT 
		DISTINCT FILENAME, 
		DATE_LOADED
	FROM LOG_STORM_DATA_LOADED
	WHERE FILENAME NOT IN 
		(
			SELECT FILENAME FROM LOG_STORM_DATA_PROCESSED
		)
	LIMIT 20
	;
    
    SELECT 'Set the log';

	TRUNCATE TABLE st_storm_data_temp;
    SELECT 'Truncated the temp table';

	INSERT INTO st_storm_data_temp
    (
		BEGIN_DATE,
        END_DATE,
        STATE,
        MONTH_NAME,
        EVENT_TYPE,
        CZ_NAME,
        INJURIES_DIRECT,
        DEATHS_DIRECT,
        INJURIES_INDIRECT,
        DEATHS_INDIRECT,
        DAMAGE_PROPERTY,
        DAMAGE_CROPS
	)
	SELECT CONCAT(STORM.BEGIN_YEARMONTH, '', 
	             	CASE WHEN LENGTH(STORM.BEGIN_DAY) = 1 THEN CONCAT('0', STORM.BEGIN_DAY)
	              	ELSE STORM.BEGIN_DAY
	              	END
	             ) BEGIN_DATE,
		CONCAT(STORM.END_YEARMONTH, '', 
	             	CASE WHEN LENGTH(STORM.BEGIN_DAY) = 1 THEN CONCAT('0', STORM.END_DAY)
	              	ELSE STORM.END_DAY
	              	END
	             ) END_DATE,
		CASE 
			WHEN STATE = 'LAKE MICHIGAN' THEN 'MICHIGAN'
	        WHEN STATE = 'LAKE ERIE' THEN 'OHIO'
	        WHEN STATE = 'LAKE HURON' THEN 'MICHIGAN'
			WHEN STATE = 'LAKE ST CLAIR' THEN 'MICHIGAN'
	        WHEN STATE = 'LAKE SUPERIOR' THEN 'MICHIGAN'
	        WHEN STATE = 'HAWAII WATERS' THEN 'HAWAII'
	        WHEN STATE = 'E PACIFIC' THEN 'CALIFORNIA'
	        WHEN STATE = 'GULF OF ALASKA' THEN 'ALASKA'
	        WHEN STATE = 'LAKE ONTARIO' THEN 'NEW YORK'
	        ELSE STATE
		END STATE,
		MONTH_NAME,
		EVENT_TYPE,
		STORM.CZ_NAME,
		IFNULL(STORM.INJURIES_INDIRECT,0)INJURIES_INDIRECT,
		IFNULL(STORM.DEATHS_DIRECT,0)DEATHS_DIRECT,
		IFNULL(STORM.INJURIES_DIRECT,0)INJURIES_DIRECT,
		IFNULL(STORM.DEATHS_INDIRECT,0)DEATHS_INDIRECT,
		REPLACE(IFNULL(STORM.DAMAGE_PROPERTY,0),"K","")*1000 DAMAGE_PROPERTY,
		REPLACE(IFNULL(STORM.DAMAGE_CROPS,0),"K","")*1000 DAMAGE_CROPS
	FROM ST_STORM_DATA  STORM
	WHERE FILENAME IN 
	(
		SELECT FILENAME FROM LOG_STORM_DATA_PROCESSING
	);

	COMMIT;
	
    SELECT 'Inserted into the temp ST';

	CALL check_disaster_dimensions();


	TRUNCATE TABLE FT_DISASTER_SUMMARY_TEMP;

	INSERT INTO FT_DISASTER_SUMMARY_TEMP
	SELECT 
	        MONTH_NAME,
	    	TMP.BEGIN_DATE,
			TMP.END_DATE,
	        STATE,
	        EVENT_TYPE,
			SUM(IFNULL(TMP.INJURIES_INDIRECT,0))INJURIES_INDIRECT,
			SUM(IFNULL(TMP.DEATHS_DIRECT,0))DEATHS_DIRECT,
			SUM(IFNULL(TMP.INJURIES_DIRECT,0))INJURIES_DIRECT,
			SUM(IFNULL(TMP.DEATHS_INDIRECT,0))DEATHS_INDIRECT,
			SUM(IFNULL(TMP.DAMAGE_PROPERTY,0))DAMAGE_PROPERTY,
			SUM(IFNULL(TMP.DAMAGE_CROPS,0))DAMAGE_CROPS,
			COUNT(*) UNITS_COUNT
	    FROM st_storm_data_temp TMP
	    GROUP BY
	        MONTH_NAME,
	    	TMP.BEGIN_DATE,
			TMP.END_DATE,
	        STATE,
	        EVENT_TYPE
	;

	COMMIT;
    SELECT 'Inserted into the temp FT';


																			
												

	TRUNCATE TABLE ft_disaster_summary;

	INSERT INTO ft_disaster_summary
	SELECT 
		TMP.BEGIN_DATE,
		TMP.END_DATE,
		STATE_ID,
		MONTH_ID,
	    DISASTER_ID,
	    TMP.INJURIES_INDIRECT,
	    TMP.DEATHS_DIRECT,
	    TMP.INJURIES_DIRECT,
	    TMP.DEATHS_INDIRECT,
	    TMP.DAMAGE_PROPERTY,
	    TMP.DAMAGE_CROPS,
	    TMP.UNITS_COUNT
	FROM 
	(	select 
			TMP.BEGIN_DATE,
			TMP.END_DATE,
			STATE.ID STATE_ID,
			MONTHS.MONTH_ID,
			TMP.MONTH_NAME,
            TMP.EVENT_TYPE,
			TMP.INJURIES_INDIRECT,
			TMP.DEATHS_DIRECT,
			TMP.INJURIES_DIRECT,
			TMP.DEATHS_INDIRECT,
			TMP.DAMAGE_PROPERTY,
			TMP.DAMAGE_CROPS,
			TMP.UNITS_COUNT
		from FT_DISASTER_SUMMARY_TEMP TMP
		JOIN STATE
		ON TMP.STATE = STATE.STATE_NAME
		JOIN DT_MONTHS MONTHS
		ON TMP.MONTH_NAME = MONTHS.MONTH_DESC
	)tmp
	JOIN DT_DISASTER_TYPES DIST
	ON TMP.EVENT_TYPE = DIST.DISASTER_DESC
;   

    INSERT INTO LOG_STORM_DATA_PROCESSED
    SELECT FILENAME, DATE_LOADED, NOW()
    FROM LOG_STORM_DATA_PROCESSING;

    SELECT 'Inserted into the Final FT';

    COMMIT;

	END WHILE check_if_finished;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `summarize_data` ()  BEGIN
	
	TRUNCATE TABLE ST_STORM_DATA_temp;

	INSERT INTO ST_STORM_DATA_temp
	SELECT CONCAT(STORM.BEGIN_YEARMONTH, '', 
	             	CASE WHEN LENGTH(STORM.BEGIN_DAY) = 1 THEN CONCAT('0', STORM.BEGIN_DAY)
	              	ELSE STORM.BEGIN_DAY
	              	END
	             ) BEGIN_DATE,
		CONCAT(STORM.END_YEARMONTH, '', 
	             	CASE WHEN LENGTH(STORM.BEGIN_DAY) = 1 THEN CONCAT('0', STORM.END_DAY)
	              	ELSE STORM.END_DAY
	              	END
	             ) END_DATE,
		CASE 
			WHEN STATE = 'LAKE MICHIGAN' THEN 'MICHIGAN'
	        WHEN STATE = 'LAKE ERIE' THEN 'OHIO'
	        WHEN STATE = 'LAKE HURON' THEN 'MICHIGAN'
			WHEN STATE = 'LAKE ST CLAIR' THEN 'MICHIGAN'
	        WHEN STATE = 'LAKE SUPERIOR' THEN 'MICHIGAN'
	        WHEN STATE = 'HAWAII WATERS' THEN 'HAWAII'
	        WHEN STATE = 'E PACIFIC' THEN 'CALIFORNIA'
	        WHEN STATE = 'GULF OF ALASKA' THEN 'ALASKA'
	        WHEN STATE = 'LAKE ONTARIO' THEN 'NEW YORK'
	        ELSE STATE
		END STATE,
		MONTH_NAME,
		EVENT_TYPE,
		CZ_NAME,
		IFNULL(STORM.INJURIES_INDIRECT,0)INJURIES_INDIRECT,
		IFNULL(STORM.DEATHS_DIRECT,0)DEATHS_DIRECT,
		IFNULL(STORM.INJURIES_DIRECT,0)INJURIES_DIRECT,
		IFNULL(STORM.DEATHS_INDIRECT,0)DEATHS_INDIRECT,
		REPLACE(IFNULL(STORM.DAMAGE_PROPERTY,0),"K","")*1000 DAMAGE_PROPERTY,
		REPLACE(IFNULL(STORM.DAMAGE_CROPS,0),"K","")*1000 DAMAGE_CROPS
	FROM ST_STORM_DATA  STORM;

	COMMIT;


	CALL check_disaster_dimensions();


	TRUNCATE TABLE ft_disaster_summary;

	INSERT INTO ft_disaster_summary
	SELECT BEGIN_DATE,
		END_DATE,
		STATE,
		MONTH_NAME,
		EVENT_TYPE,
				SUM(IFNULL(STORM.INJURIES_INDIRECT,0))INJURIES_INDIRECT,
		SUM(IFNULL(STORM.DEATHS_DIRECT,0))DEATHS_DIRECT,
		SUM(IFNULL(STORM.INJURIES_DIRECT,0))INJURIES_DIRECT,
		SUM(IFNULL(STORM.DEATHS_INDIRECT,0))DEATHS_INDIRECT,
		SUM(REPLACE(IFNULL(STORM.DAMAGE_PROPERTY,0),"K","")*1000)DAMAGE_PROPERTY,
		SUM(REPLACE(IFNULL(STORM.DAMAGE_CROPS,0),"K","")*1000)DAMAGE_CROPS,
		COUNT(*)UNITS_COUNT
	FROM ST_STORM_DATA_temp STORM
	GROUP BY 
		BEGIN_DATE,
		END_DATE,
		STATE,
		MONTH_NAME,
		EVENT_TYPE;

    COMMIT;
END$$

--
-- Functions
--
CREATE DEFINER=`root`@`localhost` FUNCTION `f_compute_state` (`state_name` VARCHAR(50)) RETURNS VARCHAR(50) CHARSET latin1 BEGIN

   DECLARE revised_name VARCHAR(50);

   SET revised_name = '';

  SELECT 
	CASE 
		WHEN name = 'U.S. Virgin Islands' 
		THEN 'VIRGIN ISLANDS'
		WHEN name = 'Washington DC' 
		THEN 'DISTRICT OF COLUMBIA'
	ELSE UPPER(name)
	END
	INTO revised_name 
	FROM state
	WHERE name = state_name;

   RETURN revised_name;

END$$

DELIMITER ;

-- --------------------------------------------------------

--
-- Table structure for table `dt_disaster_types`
--

CREATE TABLE `dt_disaster_types` (
  `DISASTER_ID` int(11) NOT NULL,
  `DISASTER_DESC` varchar(50) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

--
-- Table structure for table `dt_months`
--

CREATE TABLE `dt_months` (
  `MONTH_ID` int(11) NOT NULL,
  `MONTH_DESC` varchar(30) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

--
-- Table structure for table `dt_state`
--

CREATE TABLE `dt_state` (
  `STATE_ID` int(11) NOT NULL,
  `STATE_DESC` varchar(50) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

--
-- Table structure for table `dt_state_cz`
--

CREATE TABLE `dt_state_cz` (
  `STATE_CZ_ID` int(11) NOT NULL,
  `STATE_ID` int(11) DEFAULT NULL,
  `CZ_DESC` varchar(50) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

--
-- Table structure for table `ft_disaster_summary`
--

CREATE TABLE `ft_disaster_summary` (
  `BEGIN_DATE` varchar(22) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `END_DATE` varchar(22) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `STATE` varchar(50) DEFAULT NULL,
  `MONTH_NAME` varchar(30) DEFAULT NULL,
  `EVENT_TYPE` varchar(50) DEFAULT NULL,
  `INJURIES_INDIRECT` decimal(32,0) DEFAULT NULL,
  `DEATHS_DIRECT` decimal(32,0) DEFAULT NULL,
  `INJURIES_DIRECT` decimal(32,0) DEFAULT NULL,
  `DEATHS_INDIRECT` decimal(32,0) DEFAULT NULL,
  `DAMAGE_PROPERTY` double DEFAULT NULL,
  `DAMAGE_CROPS` double DEFAULT NULL,
  `units_count` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

--
-- Table structure for table `log_storm_data_loaded`
--

CREATE TABLE `log_storm_data_loaded` (
  `FILENAME` varchar(100) NOT NULL,
  `RECORD_COUNT` int(11) DEFAULT NULL,
  `DATE_LOADED` datetime DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

--
-- Table structure for table `state`
--

CREATE TABLE `state` (
  `id` int(11) NOT NULL,
  `name` varchar(255) DEFAULT NULL,
  `abbreviation` varchar(255) DEFAULT NULL,
  `country` varchar(255) DEFAULT NULL,
  `type` varchar(255) DEFAULT NULL,
  `sort` int(11) DEFAULT NULL,
  `status` varchar(255) DEFAULT NULL,
  `occupied` varchar(255) DEFAULT NULL,
  `notes` varchar(255) DEFAULT NULL,
  `fips_state` varchar(255) DEFAULT NULL,
  `assoc_press` varchar(255) DEFAULT NULL,
  `standard_federal_region` varchar(255) DEFAULT NULL,
  `census_region` varchar(255) DEFAULT NULL,
  `census_region_name` varchar(255) DEFAULT NULL,
  `census_division` varchar(255) DEFAULT NULL,
  `census_division_name` varchar(255) DEFAULT NULL,
  `circuit_court` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Dumping data for table `state`
--

INSERT INTO `state` (`id`, `name`, `abbreviation`, `country`, `type`, `sort`, `status`, `occupied`, `notes`, `fips_state`, `assoc_press`, `standard_federal_region`, `census_region`, `census_region_name`, `census_division`, `census_division_name`, `circuit_court`) VALUES
(-1, 'Cannot alocate event to a single state', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
(1, 'Alabama', 'AL', 'USA', 'state', 10, 'current', 'occupied', '', '1', 'Ala.', 'IV', '3', 'South', '6', 'East South Central', '11'),
(2, 'Alaska', 'AK', 'USA', 'state', 10, 'current', 'occupied', '', '2', 'Alaska', 'X', '4', 'West', '9', 'Pacific', '9'),
(3, 'Arizona', 'AZ', 'USA', 'state', 10, 'current', 'occupied', '', '4', 'Ariz.', 'IX', '4', 'West', '8', 'Mountain', '9'),
(4, 'Arkansas', 'AR', 'USA', 'state', 10, 'current', 'occupied', '', '5', 'Ark.', 'VI', '3', 'South', '7', 'West South Central', '8'),
(5, 'California', 'CA', 'USA', 'state', 10, 'current', 'occupied', '', '6', 'Calif.', 'IX', '4', 'West', '9', 'Pacific', '9'),
(6, 'Colorado', 'CO', 'USA', 'state', 10, 'current', 'occupied', '', '8', 'Colo.', 'VIII', '4', 'West', '8', 'Mountain', '10'),
(7, 'Connecticut', 'CT', 'USA', 'state', 10, 'current', 'occupied', '', '9', 'Conn.', 'I', '1', 'Northeast', '1', 'New England', '2'),
(8, 'Delaware', 'DE', 'USA', 'state', 10, 'current', 'occupied', '', '10', 'Del.', 'III', '3', 'South', '5', 'South Atlantic', '3'),
(9, 'Florida', 'FL', 'USA', 'state', 10, 'current', 'occupied', '', '12', 'Fla.', 'IV', '3', 'South', '5', 'South Atlantic', '11'),
(10, 'Georgia', 'GA', 'USA', 'state', 10, 'current', 'occupied', '', '13', 'Ga.', 'IV', '3', 'South', '5', 'South Atlantic', '11'),
(11, 'Hawaii', 'HI', 'USA', 'state', 10, 'current', 'occupied', '', '15', 'Hawaii', 'IX', '4', 'West', '9', 'Pacific', '9'),
(12, 'Idaho', 'ID', 'USA', 'state', 10, 'current', 'occupied', '', '16', 'Idaho', 'X', '4', 'West', '8', 'Mountain', '9'),
(13, 'Illinois', 'IL', 'USA', 'state', 10, 'current', 'occupied', '', '17', 'Ill.', 'V', '2', 'Midwest', '3', 'East North Central', '7'),
(14, 'Indiana', 'IN', 'USA', 'state', 10, 'current', 'occupied', '', '18', 'Ind.', 'V', '2', 'Midwest', '3', 'East North Central', '7'),
(15, 'Iowa', 'IA', 'USA', 'state', 10, 'current', 'occupied', '', '19', 'Iowa', 'VII', '2', 'Midwest', '4', 'West North Central', '8'),
(16, 'Kansas', 'KS', 'USA', 'state', 10, 'current', 'occupied', '', '20', 'Kan.', 'VII', '2', 'Midwest', '4', 'West North Central', '10'),
(17, 'Kentucky', 'KY', 'USA', 'state', 10, 'current', 'occupied', '', '21', 'Ky.', 'IV', '3', 'South', '6', 'East South Central', '6'),
(18, 'Louisiana', 'LA', 'USA', 'state', 10, 'current', 'occupied', '', '22', 'La.', 'VI', '3', 'South', '7', 'West South Central', '5'),
(19, 'Maine', 'ME', 'USA', 'state', 10, 'current', 'occupied', '', '23', 'Maine', 'I', '1', 'Northeast', '1', 'New England', '1'),
(20, 'Maryland', 'MD', 'USA', 'state', 10, 'current', 'occupied', '', '24', 'Md.', 'III', '3', 'South', '5', 'South Atlantic', '4'),
(21, 'Massachusetts', 'MA', 'USA', 'state', 10, 'current', 'occupied', '', '25', 'Mass.', 'I', '1', 'Northeast', '1', 'New England', '1'),
(22, 'Michigan', 'MI', 'USA', 'state', 10, 'current', 'occupied', '', '26', 'Mich.', 'V', '2', 'Midwest', '3', 'East North Central', '6'),
(23, 'Minnesota', 'MN', 'USA', 'state', 10, 'current', 'occupied', '', '27', 'Minn.', 'V', '2', 'Midwest', '4', 'West North Central', '8'),
(24, 'Mississippi', 'MS', 'USA', 'state', 10, 'current', 'occupied', '', '28', 'Miss.', 'IV', '3', 'South', '6', 'East South Central', '5'),
(25, 'Missouri', 'MO', 'USA', 'state', 10, 'current', 'occupied', '', '29', 'Mo.', 'VII', '2', 'Midwest', '4', 'West North Central', '8'),
(26, 'Montana', 'MT', 'USA', 'state', 10, 'current', 'occupied', '', '30', 'Mont.', 'VIII', '4', 'West', '8', 'Mountain', '9'),
(27, 'Nebraska', 'NE', 'USA', 'state', 10, 'current', 'occupied', '', '31', 'Neb.', 'VII', '2', 'Midwest', '4', 'West North Central', '8'),
(28, 'Nevada', 'NV', 'USA', 'state', 10, 'current', 'occupied', '', '32', 'Nev.', 'IX', '4', 'West', '8', 'Mountain', '9'),
(29, 'New Hampshire', 'NH', 'USA', 'state', 10, 'current', 'occupied', '', '33', 'N.H.', 'I', '1', 'Northeast', '1', 'New England', '1'),
(30, 'New Jersey', 'NJ', 'USA', 'state', 10, 'current', 'occupied', '', '34', 'N.J.', 'II', '1', 'Northeast', '2', 'Mid-Atlantic', '3'),
(31, 'New Mexico', 'NM', 'USA', 'state', 10, 'current', 'occupied', '', '35', 'N.M.', 'VI', '4', 'West', '8', 'Mountain', '10'),
(32, 'New York', 'NY', 'USA', 'state', 10, 'current', 'occupied', '', '36', 'N.Y.', 'II', '1', 'Northeast', '2', 'Mid-Atlantic', '2'),
(33, 'North Carolina', 'NC', 'USA', 'state', 10, 'current', 'occupied', '', '37', 'N.C.', 'IV', '3', 'South', '5', 'South Atlantic', '4'),
(34, 'North Dakota', 'ND', 'USA', 'state', 10, 'current', 'occupied', '', '38', 'N.D.', 'VIII', '2', 'Midwest', '4', 'West North Central', '8'),
(35, 'Ohio', 'OH', 'USA', 'state', 10, 'current', 'occupied', '', '39', 'Ohio', 'V', '2', 'Midwest', '3', 'East North Central', '6'),
(36, 'Oklahoma', 'OK', 'USA', 'state', 10, 'current', 'occupied', '', '40', 'Okla.', 'VI', '3', 'South', '7', 'West South Central', '10'),
(37, 'Oregon', 'OR', 'USA', 'state', 10, 'current', 'occupied', '', '41', 'Ore.', 'X', '4', 'West', '9', 'Pacific', '9'),
(38, 'Pennsylvania', 'PA', 'USA', 'state', 10, 'current', 'occupied', '', '42', 'Pa.', 'III', '1', 'Northeast', '2', 'Mid-Atlantic', '3'),
(39, 'Rhode Island', 'RI', 'USA', 'state', 10, 'current', 'occupied', '', '44', 'R.I.', 'I', '1', 'Northeast', '1', 'New England', '1'),
(40, 'South Carolina', 'SC', 'USA', 'state', 10, 'current', 'occupied', '', '45', 'S.C.', 'IV', '3', 'South', '5', 'South Atlantic', '4'),
(41, 'South Dakota', 'SD', 'USA', 'state', 10, 'current', 'occupied', '', '46', 'S.D.', 'VIII', '2', 'Midwest', '4', 'West North Central', '8'),
(42, 'Tennessee', 'TN', 'USA', 'state', 10, 'current', 'occupied', '', '47', 'Tenn.', 'IV', '3', 'South', '6', 'East South Central', '6'),
(43, 'Texas', 'TX', 'USA', 'state', 10, 'current', 'occupied', '', '48', 'Texas', 'VI', '3', 'South', '7', 'West South Central', '5'),
(44, 'Utah', 'UT', 'USA', 'state', 10, 'current', 'occupied', '', '49', 'Utah', 'VIII', '4', 'West', '8', 'Mountain', '10'),
(45, 'Vermont', 'VT', 'USA', 'state', 10, 'current', 'occupied', '', '50', 'Vt.', 'I', '1', 'Northeast', '1', 'New England', '2'),
(46, 'Virginia', 'VA', 'USA', 'state', 10, 'current', 'occupied', '', '51', 'Va.', 'III', '3', 'South', '5', 'South Atlantic', '4'),
(47, 'Washington', 'WA', 'USA', 'state', 10, 'current', 'occupied', '', '53', 'Wash.', 'X', '4', 'West', '9', 'Pacific', '9'),
(48, 'West Virginia', 'WV', 'USA', 'state', 10, 'current', 'occupied', '', '54', 'W.Va.', 'III', '3', 'South', '5', 'South Atlantic', '4'),
(49, 'Wisconsin', 'WI', 'USA', 'state', 10, 'current', 'occupied', '', '55', 'Wis.', 'V', '2', 'Midwest', '3', 'East North Central', '7'),
(50, 'Wyoming', 'WY', 'USA', 'state', 10, 'current', 'occupied', '', '56', 'Wyo.', 'VIII', '4', 'West', '8', 'Mountain', '10'),
(51, 'Washington DC', 'DC', 'USA', 'capitol', 10, 'current', 'occupied', '', '11', '', 'III', '3', 'South', '5', 'South Atlantic', 'D.C.'),
(52, 'Puerto Rico', 'PR', 'USA', 'commonwealth', 20, 'current', 'occupied', '', '72', '', 'II', '', '', '', '', '1'),
(53, 'U.S. Virgin Islands', 'VI', 'USA', 'territory', 20, 'current', 'occupied', '', '78', '', 'II', '', '', '', '', '3'),
(54, 'American Samoa', 'AS', 'USA', 'territory', 20, 'current', 'occupied', '', '60', '', 'IX', '', '', '', '', ''),
(55, 'Guam', 'GU', 'USA', 'territory', 20, 'current', 'occupied', '', '66', '', 'IX', '', '', '', '', '9'),
(56, 'Northern Mariana Islands', 'MP', 'USA', 'commonwealth', 20, 'current', 'occupied', '', '69', '', 'IX', '', '', '', '', '9'),
(73, 'Baker Island', '', 'USA', 'minor', 50, 'current', 'unoccupied', 'Part of “US Minor Outlying Islands”', '81', '', '', '', '', '', '', ''),
(74, 'Howland Island', '', 'USA', 'minor', 51, 'current', 'unoccupied', 'Part of “US Minor Outlying Islands”', '84', '', '', '', '', '', '', ''),
(75, 'Jarvis Island', '', 'USA', 'minor', 52, 'current', 'unoccupied', 'Part of “US Minor Outlying Islands”', '86', '', '', '', '', '', '', ''),
(76, 'Johnston Atoll', '', 'USA', 'minor', 53, 'current', 'unoccupied', 'Part of “US Minor Outlying Islands”', '67', '', '', '', '', '', '', ''),
(77, 'Midway Islands', '', 'USA', 'minor', 54, 'current', 'unoccupied', 'Part of “US Minor Outlying Islands”', '71', '', '', '', '', '', '', ''),
(78, 'Wake Island', '', 'USA', 'minor', 55, 'current', 'unoccupied', 'Part of “US Minor Outlying Islands”. Claimed by Marshall Islands.', '79', '', '', '', '', '', '', ''),
(79, 'Palmyra Atoll', '', 'USA', 'minor', 56, 'current', 'occupied', 'Part of “US Minor Outlying Islands”. Owned and Managed by The Nature Conservatory', '95', '', '', '', '', '', '', ''),
(80, 'Kingman Reef', '', 'USA', 'minor', 57, 'current', 'unoccupied', 'Part of “US Minor Outlying Islands”', '89', '', '', '', '', '', '', ''),
(81, 'Navassa Island', '', 'USA', 'minor', 58, 'current', 'unoccupied', 'Part of “US Minor Outlying Islands”. Claimed by Haiti.', '76', '', '', '', '', '', '', ''),
(82, 'Serranilla Bank', '', 'USA', 'minor', 59, 'current', 'occupied', 'Lighthouse is inhabited, but occupants are unknown', '', '', '', '', '', '', '', ''),
(83, 'Bajo Nuevo Bank', '', 'USA', 'minor', 60, 'current', 'unoccupied', 'Disputed with Colombia.  Lighthouse possibly occupied.', '', '', '', '', '', '', '', '');

-- --------------------------------------------------------

--
-- Table structure for table `st_storm_data`
--

CREATE TABLE `st_storm_data` (
  `BEGIN_YEARMONTH` int(11) NOT NULL,
  `BEGIN_DAY` int(11) NOT NULL,
  `BEGIN_TIME` int(11) NOT NULL,
  `END_YEARMONTH` int(11) NOT NULL,
  `END_DAY` int(11) NOT NULL,
  `END_TIME` int(11) NOT NULL,
  `EPISODE_ID` int(11) NOT NULL,
  `EVENT_ID` int(11) NOT NULL,
  `STATE` varchar(50) NOT NULL,
  `STATE_FIPS` int(11) NOT NULL,
  `YEAR` int(11) NOT NULL,
  `MONTH_NAME` varchar(30) NOT NULL,
  `EVENT_TYPE` varchar(50) NOT NULL,
  `CZ_TYPE` varchar(1) NOT NULL,
  `CZ_FIPS` int(11) NOT NULL,
  `CZ_NAME` varchar(50) NOT NULL,
  `WFO` varchar(10) NOT NULL,
  `BEGIN_DATE_TIME` datetime NOT NULL,
  `CZ_TIMEZONE` varchar(5) NOT NULL,
  `END_DATE_TIME` datetime NOT NULL,
  `INJURIES_DIRECT` int(11) NOT NULL,
  `INJURIES_INDIRECT` int(11) NOT NULL,
  `DEATHS_DIRECT` int(11) NOT NULL,
  `DEATHS_INDIRECT` int(11) NOT NULL,
  `DAMAGE_PROPERTY` varchar(10) NOT NULL,
  `DAMAGE_CROPS` varchar(10) NOT NULL,
  `SOURCE` varchar(50) NOT NULL,
  `MAGNITUDE` int(11) NOT NULL,
  `MAGNITUDE_TYPE` varchar(10) NOT NULL,
  `FLOOD_CAUSE` varchar(50) NOT NULL,
  `CATEGORY` varchar(10) NOT NULL,
  `TOR_F_SCALE` varchar(5) NOT NULL,
  `TOR_LENGTH` float NOT NULL,
  `TOR_WIDTH` int(11) NOT NULL,
  `TOR_OTHER_WFO` varchar(500) NOT NULL,
  `TOR_OTHER_CZ_STATE` varchar(500) NOT NULL,
  `TOR_OTHER_CZ_FIPS` varchar(50) NOT NULL,
  `TOR_OTHER_CZ_NAME` varchar(50) NOT NULL,
  `BEGIN_RANGE` int(11) NOT NULL,
  `BEGIN_AZIMUTH` varchar(10) NOT NULL,
  `BEGIN_LOCATION` varchar(50) NOT NULL,
  `END_RANGE` int(11) NOT NULL,
  `END_AZIMUTH` varchar(5) NOT NULL,
  `END_LOCATION` varchar(50) NOT NULL,
  `BEGIN_LAT` float NOT NULL,
  `BEGIN_LON` float NOT NULL,
  `END_LAT` float NOT NULL,
  `END_LON` float NOT NULL,
  `EPISODE_NARRATIVE` blob NOT NULL,
  `EVENT_NARRATIVE` blob NOT NULL,
  `DATA_SOURCE` varchar(50) NOT NULL,
  `FILENAME` varchar(100) DEFAULT NULL,
  `date_loaded` datetime DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

--
-- Table structure for table `st_storm_data_temp`
--

CREATE TABLE `st_storm_data_temp` (
  `BEGIN_DATE` varchar(22) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `END_DATE` varchar(22) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `STATE` varchar(50),
  `MONTH_NAME` varchar(30),
  `EVENT_TYPE` varchar(50),
  `CZ_NAME` varchar(50) NOT NULL,
  `INJURIES_INDIRECT` decimal(32,0) DEFAULT NULL,
  `DEATHS_DIRECT` decimal(32,0) DEFAULT NULL,
  `INJURIES_DIRECT` decimal(32,0) DEFAULT NULL,
  `DEATHS_INDIRECT` decimal(32,0) DEFAULT NULL,
  `DAMAGE_PROPERTY` double DEFAULT NULL,
  `DAMAGE_CROPS` double DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Indexes for dumped tables
--

--
-- Indexes for table `dt_disaster_types`
--
ALTER TABLE `dt_disaster_types`
  ADD PRIMARY KEY (`DISASTER_ID`);

--
-- Indexes for table `dt_months`
--
ALTER TABLE `dt_months`
  ADD PRIMARY KEY (`MONTH_ID`);

--
-- Indexes for table `dt_state`
--
ALTER TABLE `dt_state`
  ADD PRIMARY KEY (`STATE_ID`);

--
-- Indexes for table `dt_state_cz`
--
ALTER TABLE `dt_state_cz`
  ADD PRIMARY KEY (`STATE_CZ_ID`),
  ADD KEY `STATE_ID` (`STATE_ID`);

--
-- Indexes for table `ft_disaster_summary`
--
ALTER TABLE `ft_disaster_summary`
  ADD KEY `IDX_FT_DS_SUMMARY` (`BEGIN_DATE`(8)),
  ADD KEY `IDX_FT_DS_SUMMARY_STATE` (`STATE`);

--
-- Indexes for table `state`
--
ALTER TABLE `state`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `st_storm_data`
--
ALTER TABLE `st_storm_data`
  ADD KEY `IDX_ST_STORM_DT_DATE` (`BEGIN_YEARMONTH`,`BEGIN_DAY`),
  ADD KEY `IDX_ST_DATA_FILENAME` (`FILENAME`);

--
-- Indexes for table `st_storm_data_temp`
--
ALTER TABLE `st_storm_data_temp`
  ADD KEY `idx_st_temp` (`STATE`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `dt_disaster_types`
--
ALTER TABLE `dt_disaster_types`
  MODIFY `DISASTER_ID` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=10074;
--
-- AUTO_INCREMENT for table `dt_months`
--
ALTER TABLE `dt_months`
  MODIFY `MONTH_ID` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=13;
--
-- AUTO_INCREMENT for table `dt_state`
--
ALTER TABLE `dt_state`
  MODIFY `STATE_ID` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=169;
--
-- AUTO_INCREMENT for table `dt_state_cz`
--
ALTER TABLE `dt_state_cz`
  MODIFY `STATE_CZ_ID` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=6701;
--
-- Constraints for dumped tables
--

--
-- Constraints for table `dt_state_cz`
--
ALTER TABLE `dt_state_cz`
  ADD CONSTRAINT `dt_state_cz_ibfk_1` FOREIGN KEY (`STATE_ID`) REFERENCES `state` (`id`);

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
