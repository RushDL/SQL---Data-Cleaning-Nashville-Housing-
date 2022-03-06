-- Objective: Data cleaning and updating the data on the database. 


-----------------------------------------------------------------------------------------------------------------------------------------------

-- Check data types for each column.

SELECT
	COLUMN_NAME,
	DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'NashvilleHousing'


SELECT
	*
FROM PortfolioProject.dbo.NashvilleHousing

-- To do:
-- 1. Make sure Variables in columns 'LandUse' and 'SolidAsVacant' are consistent. 
-- 2. Populate Property address
-- 3. Create new columns for 'address' and 'city' using the 'PropertyAddress' column.
-- 4. Create new columns for 'address', 'city' and 'state' using the 'OwnerAddress' column.
-- 5. Change the datatype of 'SalesDate' from datetime to date only.
-- 6. Remove Duplicates
-- 7. Drop Unused Columns




-----------------------------------------------------------------------------------------------------------------------------------------------

-- 1. Make sure Variables in columns 'LandUse' and 'SolidAsVacant' are consistent.


SELECT
	DISTINCT LandUse,
	COUNT (LandUse) AS Count
FROM PortfolioProject.dbo.NashvilleHousing
GROUP BY LandUse
ORDER BY LandUse



----- a. Change 'VACANT RES LAND' AND 'VACANT RESIENTIAL LAND' into 'VACANT RESIDENTIAL LAND'


UPDATE PortfolioProject.dbo.NashvilleHousing
SET LandUse = 'VACANT RESIDENTIAL LAND'
WHERE LandUse = 'VACANT RES LAND' OR LandUse = 'VACANT RESIENTIAL LAND'



----- b. Change 'RESIDENTIAL COMBO/MISC' to 'RESIDENTIAL CONDO'


UPDATE PortfolioProject.dbo.NashvilleHousing
SET LandUse = 'RESIDENTIAL CONDO'
WHERE LandUse = 'RESIDENTIAL COMBO/MISC'




----- c. Standardize categorical variables in column 'SolidAsVacant'. 

SELECT
	DISTINCT SoldAsVacant,
	COUNT (SoldAsVacant) AS sub_count
FROM PortfolioProject.dbo.NashvilleHousing
GROUP BY SoldAsVacant
ORDER BY SoldAsVacant



Select 
	SoldAsVacant,
	CASE When SoldAsVacant = 'Y' THEN 'Yes'
		 When SoldAsVacant = 'N' THEN 'No'
		 ELSE SoldAsVacant
		 END
From PortfolioProject.dbo.NashvilleHousing



UPDATE NashvilleHousing
SET SoldAsVacant = CASE When SoldAsVacant = 'Y' THEN 'Yes'
						When SoldAsVacant = 'N' THEN 'No'
						ELSE SoldAsVacant
						END




-----------------------------------------------------------------------------------------------------------------------------------------------

-- 2. Populate Property address.


SELECT
	*
FROM PortfolioProject.dbo.NashvilleHousing
--WHERE PropertyAddress IS NULL
ORDER BY ParcelID




----- Use the 'ParcelID' to populate the missing property address. Use self join to populate.  


SELECT
	a.ParcelID,
	a.PropertyAddress,
	b.ParcelID,
	b.PropertyAddress
FROM PortfolioProject.dbo.NashvilleHousing AS a
JOIN PortfolioProject.dbo.NashvilleHousing AS b
	ON a.ParcelID = b.ParcelID
	AND a.[UniqueID ] <> b.[UniqueID ]
WHERE a.PropertyAddress IS NULL


UPDATE a
SET PropertyAddress = ISNULL(a.PropertyAddress, b.PropertyAddress)
FROM PortfolioProject.dbo.NashvilleHousing AS a
JOIN PortfolioProject.dbo.NashvilleHousing AS b
	ON a.ParcelID = b.ParcelID
	AND a.[UniqueID ] <> b.[UniqueID ]
WHERE a.PropertyAddress IS NULL








-----------------------------------------------------------------------------------------------------------------------------------------------

-- 3. Create new columns for 'address' and 'city' using the 'PropertyAddress' column.


SELECT PropertyAddress
FROM PortfolioProject.dbo.NashvilleHousing 


SELECT
	PropertyAddress,
	SUBSTRING(PropertyAddress, 1, CHARINDEX(',',PropertyAddress) -1) AS Address,
	SUBSTRING(PropertyAddress, CHARINDEX(',',PropertyAddress) +1, LEN(PropertyAddress)) AS City
FROM PortfolioProject.dbo.NashvilleHousing 




----- Insert new columns and update the table. The 'ALTER TABLE' and 'ADD' function let you create a new column in the main table in the database. 


ALTER TABLE NashvilleHousing
Add PropertySplitAddress Nvarchar(255),
	PropertySplitCity Nvarchar(255);


UPDATE NashvilleHousing
SET PropertySplitAddress = SUBSTRING(PropertyAddress, 1, CHARINDEX(',',PropertyAddress) -1),
SET PropertySplitCity = SUBSTRING(PropertyAddress, CHARINDEX(',',PropertyAddress) +1, LEN(PropertyAddress))






-------------------------------------------------------------------------------------------------------------------------------------------------

-- 4. Create new columns for 'address', 'city' and 'state' using the 'OwnerAddress' column.
----- Parsname help us parse the owneraddress using delimiters. But the only delimtter that it recognizes is a dot(.). So we will replace those comma's with a dot.


SELECT
	OwnerAddress,
	PARSENAME(REPLACE(Owneraddress,',', '.'), 3) AS OwnerSplitAddress, 
	PARSENAME(REPLACE(Owneraddress,',', '.'), 2) AS OwnerSplitCity,
	PARSENAME(REPLACE(Owneraddress,',', '.'), 1) AS OwnerSplitState
FROM PortfolioProject.dbo.NashvilleHousing
WHERE OwnerAddress IS NOT NULL


ALTER TABLE NashvilleHousing
ADD 
	OwnerSplitAddress Nvarchar(255),
	OwnerSplitCity Nvarchar(255),
	OwnerSplitState Nvarchar(255);


Update NashvilleHousing
SET
	OwnerSplitAddress = PARSENAME(REPLACE(Owneraddress,',', '.'), 3),
	OwnerSplitCity = PARSENAME(REPLACE(Owneraddress,',', '.'), 2),
	OwnerSplitState = PARSENAME(REPLACE(Owneraddress,',', '.'), 1)



SELECT 
	*
FROM NashvilleHousing







-------------------------------------------------------------------------------------------------------------------------------------------------

-- 5.Change the datatype of 'SalesDate' from datetime to date only.

SELECT
	SaleDate,
	CAST (SaleDate AS DATE)
FROM NashvilleHousing


UPDATE NashvilleHousing
SET SaleDate = CAST (SaleDate AS DATE)


----- The date format was not properly updated in the database. Therefore, we will create a new column.

ALTER TABLE NashvilleHousing
ADD SaleDateConverted Date;


UPDATE NashvilleHousing
SET SaleDateConverted = CAST (SaleDate AS DATE);








-------------------------------------------------------------------------------------------------------------------------------------------------

-- 6. Remove Duplicates
----- We create a temporary table to remove these duplicates. It is not a standard process to remove duplicates in the database.


----- a. ROW_NUMBER -> Assigns a sequential integer to each row within the partion of a result. Similar to RANK()
----- b. PARTITION BY -> clause divides the result set into group of rows. 
----- c. ORDER BY -> Clause defines the logical order of rows within partition of result set. (Mandatory)



WITH RowNumCTE AS(
SELECT
	*,
	ROW_NUMBER() OVER (
	PARTITION BY ParcelID,
				 PropertyAddress,
				 SaleDate,
				 SalePrice,
				 LegalReference
				 ORDER BY
					UniqueID
				 ) AS RowNum
FROM PortfolioProject.dbo.NashvilleHousing
)

DELETE 
FROM RowNumCTE
WHERE RowNum > 1
--ORDER BY PropertyAddress



Select *
From PortfolioProject.dbo.NashvilleHousing






-------------------------------------------------------------------------------------------------------------------------------------------------

-- 7. Remove unused columns. Note: Before removing columns in the database, CONSULT FIRST and ASK PERMISSION. 

Select *
From PortfolioProject.dbo.NashvilleHousing


ALTER TABLE PortfolioProject.dbo.NashvilleHousing
DROP COLUMN PropertyAddress,
			SaleDate,
			OwnerAddress,
			TaxDistrict

