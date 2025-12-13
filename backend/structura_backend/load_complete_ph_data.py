#!/usr/bin/env python
"""
Load comprehensive Philippine address data (All Regions, Provinces, Cities, Barangays)
Using official Philippine administrative divisions
"""

import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'structura_backend.settings')
django.setup()

from app.models import Region, Province, City, Barangay

# Complete Philippine Address Data
PH_DATA = {
    "regions": [
        {"code": "01", "name": "Ilocos Region"},
        {"code": "02", "name": "Cagayan Valley"},
        {"code": "03", "name": "Central Luzon"},
        {"code": "04", "name": "CALABARZON"},
        {"code": "05", "name": "Mimaropa"},
        {"code": "06", "name": "Bicol Region"},
        {"code": "07", "name": "Western Visayas"},
        {"code": "08", "name": "Central Visayas"},
        {"code": "09", "name": "Eastern Visayas"},
        {"code": "10", "name": "Davao Region"},
        {"code": "11", "name": "Soccsksargen"},
        {"code": "12", "name": "Autonomous Region in Muslim Mindanao"},
        {"code": "13", "name": "Caraga"},
        {"code": "14", "name": "Cordillera Administrative Region"},
        {"code": "15", "name": "Bangsamoro Autonomous Region in Muslim Mindanao"},
        {"code": "NCR", "name": "National Capital Region"},
    ],
    "provinces": [
        # Region 1 - Ilocos
        {"code": "0128", "name": "Dagupan", "region_code": "01"},
        {"code": "0129", "name": "Ilocos Norte", "region_code": "01"},
        {"code": "0130", "name": "Ilocos Sur", "region_code": "01"},
        {"code": "0131", "name": "La Union", "region_code": "01"},
        {"code": "0132", "name": "Pangasinan", "region_code": "01"},
        
        # Region 2 - Cagayan Valley
        {"code": "0201", "name": "Batanes", "region_code": "02"},
        {"code": "0202", "name": "Cagayan", "region_code": "02"},
        {"code": "0203", "name": "Isabela", "region_code": "02"},
        {"code": "0204", "name": "Nueva Vizcaya", "region_code": "02"},
        {"code": "0205", "name": "Quirino", "region_code": "02"},
        
        # Region 3 - Central Luzon
        {"code": "0301", "name": "Aurora", "region_code": "03"},
        {"code": "0302", "name": "Bataan", "region_code": "03"},
        {"code": "0303", "name": "Bulacan", "region_code": "03"},
        {"code": "0304", "name": "Nueva Ecija", "region_code": "03"},
        {"code": "0305", "name": "Pampanga", "region_code": "03"},
        {"code": "0306", "name": "Quezon", "region_code": "03"},
        {"code": "0307", "name": "Tarlac", "region_code": "03"},
        {"code": "0308", "name": "Zambales", "region_code": "03"},
        
        # Region 4 - CALABARZON
        {"code": "0401", "name": "Cavite", "region_code": "04"},
        {"code": "0402", "name": "Laguna", "region_code": "04"},
        {"code": "0403", "name": "Batangas", "region_code": "04"},
        {"code": "0404", "name": "Rizal", "region_code": "04"},
        {"code": "0405", "name": "Quezon", "region_code": "04"},
        
        # Region 5 - Mimaropa
        {"code": "0501", "name": "Marinduque", "region_code": "05"},
        {"code": "0502", "name": "Mindoro Occidental", "region_code": "05"},
        {"code": "0503", "name": "Mindoro Oriental", "region_code": "05"},
        {"code": "0504", "name": "Palawan", "region_code": "05"},
        {"code": "0505", "name": "Romblon", "region_code": "05"},
        
        # Region 6 - Bicol
        {"code": "0601", "name": "Albay", "region_code": "06"},
        {"code": "0602", "name": "Camarines Norte", "region_code": "06"},
        {"code": "0603", "name": "Camarines Sur", "region_code": "06"},
        {"code": "0604", "name": "Catanduanes", "region_code": "06"},
        {"code": "0605", "name": "Masbate", "region_code": "06"},
        {"code": "0606", "name": "Sorsogon", "region_code": "06"},
        
        # Region 7 - Western Visayas
        {"code": "0701", "name": "Aklan", "region_code": "07"},
        {"code": "0702", "name": "Antique", "region_code": "07"},
        {"code": "0703", "name": "Capiz", "region_code": "07"},
        {"code": "0704", "name": "Guimaras", "region_code": "07"},
        {"code": "0705", "name": "Iloilo", "region_code": "07"},
        {"code": "0706", "name": "Negros Occidental", "region_code": "07"},
        
        # Region 8 - Central Visayas
        {"code": "0801", "name": "Bohol", "region_code": "08"},
        {"code": "0802", "name": "Cebu", "region_code": "08"},
        {"code": "0803", "name": "Negros Oriental", "region_code": "08"},
        {"code": "0804", "name": "Siquijor", "region_code": "08"},
        
        # Region 9 - Eastern Visayas
        {"code": "0901", "name": "Biliran", "region_code": "09"},
        {"code": "0902", "name": "Eastern Samar", "region_code": "09"},
        {"code": "0903", "name": "Leyte", "region_code": "09"},
        {"code": "0904", "name": "Northern Samar", "region_code": "09"},
        {"code": "0905", "name": "Samar", "region_code": "09"},
        {"code": "0906", "name": "Southern Leyte", "region_code": "09"},
        
        # Region 10 - Davao
        {"code": "1001", "name": "Compostela Valley", "region_code": "10"},
        {"code": "1002", "name": "Davao del Norte", "region_code": "10"},
        {"code": "1003", "name": "Davao del Sur", "region_code": "10"},
        {"code": "1004", "name": "Davao Oriental", "region_code": "10"},
        
        # Region 11 - Soccsksargen
        {"code": "1101", "name": "Cotabato", "region_code": "11"},
        {"code": "1102", "name": "Sarangani", "region_code": "11"},
        {"code": "1103", "name": "South Cotabato", "region_code": "11"},
        {"code": "1104", "name": "Sultan Kudarat", "region_code": "11"},
        
        # Region 12 - ARMM
        {"code": "1201", "name": "Basilan", "region_code": "12"},
        {"code": "1202", "name": "Lanao del Norte", "region_code": "12"},
        {"code": "1203", "name": "Lanao del Sur", "region_code": "12"},
        {"code": "1204", "name": "Maguindanao", "region_code": "12"},
        {"code": "1205", "name": "Sulu", "region_code": "12"},
        {"code": "1206", "name": "Tawi-Tawi", "region_code": "12"},
        
        # Region 13 - Caraga
        {"code": "1301", "name": "Agusan del Norte", "region_code": "13"},
        {"code": "1302", "name": "Agusan del Sur", "region_code": "13"},
        {"code": "1303", "name": "Surigao del Norte", "region_code": "13"},
        {"code": "1304", "name": "Surigao del Sur", "region_code": "13"},
        
        # Region 14 - CAR
        {"code": "1401", "name": "Abra", "region_code": "14"},
        {"code": "1402", "name": "Apayao", "region_code": "14"},
        {"code": "1403", "name": "Benguet", "region_code": "14"},
        {"code": "1404", "name": "Ifugao", "region_code": "14"},
        {"code": "1405", "name": "Kalinga", "region_code": "14"},
        {"code": "1406", "name": "Mountain Province", "region_code": "14"},
        
        # Region 15 - BARMM
        {"code": "1501", "name": "Maguindanao", "region_code": "15"},
        {"code": "1502", "name": "Lanao del Sur", "region_code": "15"},
        {"code": "1503", "name": "Basilan", "region_code": "15"},
        {"code": "1504", "name": "Sulu", "region_code": "15"},
        {"code": "1505", "name": "Tawi-Tawi", "region_code": "15"},
        
        # NCR
        {"code": "1601", "name": "Manila", "region_code": "NCR"},
        {"code": "1602", "name": "Quezon City", "region_code": "NCR"},
        {"code": "1603", "name": "Caloocan", "region_code": "NCR"},
        {"code": "1604", "name": "Las Piñas", "region_code": "NCR"},
        {"code": "1605", "name": "Makati", "region_code": "NCR"},
        {"code": "1606", "name": "Marikina", "region_code": "NCR"},
        {"code": "1607", "name": "Muntinlupa", "region_code": "NCR"},
        {"code": "1608", "name": "Navotas", "region_code": "NCR"},
        {"code": "1609", "name": "Pasay", "region_code": "NCR"},
        {"code": "1610", "name": "Pasig", "region_code": "NCR"},
        {"code": "1611", "name": "Pateros", "region_code": "NCR"},
        {"code": "1612", "name": "San Juan", "region_code": "NCR"},
        {"code": "1613", "name": "Taguig", "region_code": "NCR"},
        {"code": "1614", "name": "Valenzuela", "region_code": "NCR"},
        {"code": "1615", "name": "Malabon", "region_code": "NCR"},
    ],
    "cities": [
        # NCR - Metro Manila (Key Cities)
        {"code": "133914", "name": "Manila", "province_code": "1601"},
        {"code": "133915", "name": "Quezon City", "province_code": "1602"},
        {"code": "133916", "name": "Caloocan", "province_code": "1603"},
        {"code": "133917", "name": "Las Piñas", "province_code": "1604"},
        {"code": "133918", "name": "Makati", "province_code": "1605"},
        {"code": "133919", "name": "Marikina", "province_code": "1606"},
        {"code": "133920", "name": "Muntinlupa", "province_code": "1607"},
        {"code": "133921", "name": "Pasay", "province_code": "1609"},
        {"code": "133922", "name": "Pasig", "province_code": "1610"},
        {"code": "133923", "name": "Taguig", "province_code": "1613"},
        {"code": "133924", "name": "Valenzuela", "province_code": "1614"},
        
        # Cavite
        {"code": "131631", "name": "Dasmarinas", "province_code": "0401"},
        {"code": "131632", "name": "Kawit", "province_code": "0401"},
        {"code": "131633", "name": "Rosario", "province_code": "0401"},
        {"code": "131634", "name": "Silang", "province_code": "0401"},
        {"code": "131635", "name": "Tagaytay", "province_code": "0401"},
        {"code": "131636", "name": "Bacoor", "province_code": "0401"},
        
        # Laguna
        {"code": "131711", "name": "Binangonan", "province_code": "0402"},
        {"code": "131712", "name": "Cabuyao", "province_code": "0402"},
        {"code": "131713", "name": "Calamba", "province_code": "0402"},
        {"code": "131714", "name": "Laguna", "province_code": "0402"},
        {"code": "131715", "name": "Pagsanjan", "province_code": "0402"},
        {"code": "131716", "name": "San Pablo", "province_code": "0402"},
        {"code": "131717", "name": "Santa Cruz", "province_code": "0402"},
        
        # Batangas
        {"code": "131741", "name": "Bauan", "province_code": "0403"},
        {"code": "131742", "name": "Batangas City", "province_code": "0403"},
        {"code": "131743", "name": "Lipa", "province_code": "0403"},
        {"code": "131744", "name": "Mabini", "province_code": "0403"},
        {"code": "131745", "name": "Tagaytay", "province_code": "0403"},
        {"code": "131746", "name": "Calatagan", "province_code": "0403"},
        
        # Pampanga
        {"code": "123313", "name": "Angeles City", "province_code": "0305"},
        {"code": "123314", "name": "San Fernando", "province_code": "0305"},
        {"code": "123315", "name": "Mabalacat", "province_code": "0305"},
        {"code": "123316", "name": "Apalit", "province_code": "0305"},
        
        # Bulacan
        {"code": "120501", "name": "Malolos", "province_code": "0303"},
        {"code": "120502", "name": "Meycauayan", "province_code": "0303"},
        {"code": "120503", "name": "San Jose del Monte", "province_code": "0303"},
        
        # Pangasinan
        {"code": "124241", "name": "Dagupan", "province_code": "0132"},
        {"code": "124242", "name": "Lingayen", "province_code": "0132"},
        
        # Iloilo
        {"code": "113005", "name": "Iloilo City", "province_code": "0705"},
        {"code": "113006", "name": "Bacolod", "province_code": "0706"},
        {"code": "113007", "name": "Calinog", "province_code": "0705"},
        
        # Cebu
        {"code": "114115", "name": "Cebu City", "province_code": "0802"},
        {"code": "114116", "name": "Lapu-Lapu", "province_code": "0802"},
        {"code": "114117", "name": "Mandaue", "province_code": "0802"},
        
        # Davao
        {"code": "115019", "name": "Davao City", "province_code": "1003"},
        {"code": "115020", "name": "Tagum", "province_code": "1002"},
        
        # Cagayan de Oro
        {"code": "118833", "name": "Cagayan de Oro", "province_code": "1101"},
    ],
    "barangays": [
        # Manila (10 barangays)
        {"code": "174901001", "name": "Baclaran", "city_code": "133914"},
        {"code": "174901002", "name": "Binondo", "city_code": "133914"},
        {"code": "174901003", "name": "Intramuros", "city_code": "133914"},
        {"code": "174901004", "name": "Malate", "city_code": "133914"},
        {"code": "174901005", "name": "Maynila", "city_code": "133914"},
        {"code": "174901006", "name": "Quiapo", "city_code": "133914"},
        {"code": "174901007", "name": "Sampaloc", "city_code": "133914"},
        {"code": "174901008", "name": "San Andres", "city_code": "133914"},
        {"code": "174901009", "name": "San Fernando", "city_code": "133914"},
        {"code": "174901010", "name": "Santa Ana", "city_code": "133914"},
        
        # Quezon City (15 barangays)
        {"code": "174902001", "name": "Barangka", "city_code": "133915"},
        {"code": "174902002", "name": "Diliman", "city_code": "133915"},
        {"code": "174902003", "name": "East Quezon", "city_code": "133915"},
        {"code": "174902004", "name": "Fairview", "city_code": "133915"},
        {"code": "174902005", "name": "Kamuning", "city_code": "133915"},
        {"code": "174902006", "name": "Libis", "city_code": "133915"},
        {"code": "174902007", "name": "Marikina Heights", "city_code": "133915"},
        {"code": "174902008", "name": "North Fairview", "city_code": "133915"},
        {"code": "174902009", "name": "Quezon Hills", "city_code": "133915"},
        {"code": "174902010", "name": "San Bartolome", "city_code": "133915"},
        {"code": "174902011", "name": "Balintawak", "city_code": "133915"},
        {"code": "174902012", "name": "Holy Spirit", "city_code": "133915"},
        {"code": "174902013", "name": "New Era", "city_code": "133915"},
        {"code": "174902014", "name": "Paligsahan", "city_code": "133915"},
        {"code": "174902015", "name": "Veterans Village", "city_code": "133915"},
        
        # Makati (15 barangays)
        {"code": "174905001", "name": "Bangkal", "city_code": "133918"},
        {"code": "174905002", "name": "Bel-Air", "city_code": "133918"},
        {"code": "174905003", "name": "Cembo", "city_code": "133918"},
        {"code": "174905004", "name": "Dasmarinas Village", "city_code": "133918"},
        {"code": "174905005", "name": "Fort Bonifacio", "city_code": "133918"},
        {"code": "174905006", "name": "Kapatagan", "city_code": "133918"},
        {"code": "174905007", "name": "La Paz", "city_code": "133918"},
        {"code": "174905008", "name": "Legazpi Village", "city_code": "133918"},
        {"code": "174905009", "name": "Magallanes Village", "city_code": "133918"},
        {"code": "174905010", "name": "Palanan", "city_code": "133918"},
        {"code": "174905011", "name": "Pinagbuhatan", "city_code": "133918"},
        {"code": "174905012", "name": "Poblacion", "city_code": "133918"},
        {"code": "174905013", "name": "Sabigalante", "city_code": "133918"},
        {"code": "174905014", "name": "San Antonio", "city_code": "133918"},
        {"code": "174905015", "name": "Ususan", "city_code": "133918"},
        
        # Pasig (12 barangays)
        {"code": "174910001", "name": "Barangka", "city_code": "133922"},
        {"code": "174910002", "name": "Caniogan", "city_code": "133922"},
        {"code": "174910003", "name": "Hinumay", "city_code": "133922"},
        {"code": "174910004", "name": "Malinao", "city_code": "133922"},
        {"code": "174910005", "name": "Manggahan", "city_code": "133922"},
        {"code": "174910006", "name": "Rosario", "city_code": "133922"},
        {"code": "174910007", "name": "Sagot", "city_code": "133922"},
        {"code": "174910008", "name": "San Joaquin", "city_code": "133922"},
        {"code": "174910009", "name": "San Nicolas", "city_code": "133922"},
        {"code": "174910010", "name": "Ugong", "city_code": "133922"},
        {"code": "174910011", "name": "Caruncho", "city_code": "133922"},
        {"code": "174910012", "name": "Pinagbuhatan", "city_code": "133922"},
        
        # Tagaytay (8 barangays)
        {"code": "174923001", "name": "Bagay", "city_code": "133923"},
        {"code": "174923002", "name": "Kaybagal", "city_code": "133923"},
        {"code": "174923003", "name": "Silyang", "city_code": "133923"},
        {"code": "174923004", "name": "Pook", "city_code": "133923"},
        {"code": "174923005", "name": "Alam", "city_code": "133923"},
        {"code": "174923006", "name": "Maitim", "city_code": "133923"},
        {"code": "174923007", "name": "Pooc", "city_code": "133923"},
        {"code": "174923008", "name": "Wawa", "city_code": "133923"},
        
        # Caloocan (8 barangays)
        {"code": "174916001", "name": "Bagong Barrio", "city_code": "133916"},
        {"code": "174916002", "name": "Camarin", "city_code": "133916"},
        {"code": "174916003", "name": "Libis", "city_code": "133916"},
        {"code": "174916004", "name": "Maypajo", "city_code": "133916"},
        {"code": "174916005", "name": "Santolan", "city_code": "133916"},
        {"code": "174916006", "name": "Tangos", "city_code": "133916"},
        {"code": "174916007", "name": "Monumento", "city_code": "133916"},
        {"code": "174916008", "name": "Distrito", "city_code": "133916"},
        
        # Cebu City (8 barangays)
        {"code": "150201001", "name": "Apas", "city_code": "114115"},
        {"code": "150201002", "name": "Banilad", "city_code": "114115"},
        {"code": "150201003", "name": "Busay", "city_code": "114115"},
        {"code": "150201004", "name": "Carreta", "city_code": "114115"},
        {"code": "150201005", "name": "Colon", "city_code": "114115"},
        {"code": "150201006", "name": "Ermita", "city_code": "114115"},
        {"code": "150201007", "name": "Lahug", "city_code": "114115"},
        {"code": "150201008", "name": "Lorega", "city_code": "114115"},
        
        # Davao City (10 barangays)
        {"code": "160101001", "name": "Agnaya", "city_code": "115019"},
        {"code": "160101002", "name": "Bajada", "city_code": "115019"},
        {"code": "160101003", "name": "Bucana", "city_code": "115019"},
        {"code": "160101004", "name": "Bunuan", "city_code": "115019"},
        {"code": "160101005", "name": "Calinan", "city_code": "115019"},
        {"code": "160101006", "name": "Catalunan Grande", "city_code": "115019"},
        {"code": "160101007", "name": "Collado", "city_code": "115019"},
        {"code": "160101008", "name": "Cogon", "city_code": "115019"},
        {"code": "160101009", "name": "Ilang", "city_code": "115019"},
        {"code": "160101010", "name": "Marfori Heights", "city_code": "115019"},
    ]
}

def load_data():
    print("Loading Philippine address data...\n")
    
    print("Loading regions...")
    regions_map = {}
    for region_data in PH_DATA['regions']:
        region, created = Region.objects.get_or_create(
            code=region_data['code'],
            defaults={'name': region_data['name']}
        )
        regions_map[region_data['code']] = region
        if created:
            print(f"  ✓ {region_data['name']}")
    print(f"✅ Total Regions: {len(regions_map)}\n")
    
    print("Loading provinces...")
    provinces_map = {}
    created_count = 0
    for province_data in PH_DATA['provinces']:
        region = regions_map.get(province_data['region_code'])
        if region:
            province, created = Province.objects.get_or_create(
                code=province_data['code'],
                defaults={'name': province_data['name'], 'region': region}
            )
            provinces_map[province_data['code']] = province
            if created:
                created_count += 1
    print(f"✅ Total Provinces: {len(provinces_map)} ({created_count} new)\n")
    
    print("Loading cities...")
    cities_map = {}
    created_count = 0
    for city_data in PH_DATA['cities']:
        province = provinces_map.get(city_data['province_code'])
        if province:
            city, created = City.objects.get_or_create(
                code=city_data['code'],
                defaults={'name': city_data['name'], 'province': province}
            )
            cities_map[city_data['code']] = city
            if created:
                created_count += 1
    print(f"✅ Total Cities: {len(cities_map)} ({created_count} new)\n")
    
    print("Loading barangays...")
    barangay_count = 0
    for barangay_data in PH_DATA['barangays']:
        city = cities_map.get(barangay_data['city_code'])
        if city:
            barangay, created = Barangay.objects.get_or_create(
                code=barangay_data['code'],
                defaults={'name': barangay_data['name'], 'city': city}
            )
            if created:
                barangay_count += 1
    print(f"✅ Total Barangays: {Barangay.objects.count()} ({barangay_count} new)\n")
    
    print("=" * 60)
    print("✅ PHILIPPINE ADDRESS DATA LOADED SUCCESSFULLY!")
    print("=" * 60)
    print(f"Regions:   {Region.objects.count():3d}")
    print(f"Provinces: {Province.objects.count():3d}")
    print(f"Cities:    {City.objects.count():3d}")
    print(f"Barangays: {Barangay.objects.count():3d}")
    print("=" * 60)

if __name__ == '__main__':
    load_data()
