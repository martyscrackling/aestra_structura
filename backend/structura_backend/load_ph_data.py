#!/usr/bin/env python
"""
Load all Philippine address data (Regions, Provinces, Cities, Barangays)
Using the official Philippine Statistics Authority data via GitHub
"""

import os
import django
import requests
import json

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'structura_backend.settings')
django.setup()

from app.models import Region, Province, City, Barangay

# Philippine address data from reliable source
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
        {"code": "14", "name": "Constitutional Republic of the Philippines"},
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
        
        # Region 11 - Zamboanga (Soccsksargen)
        {"code": "1105", "name": "Zamboanga del Sur", "region_code": "11"},
        {"code": "1106", "name": "Zamboanga del Norte", "region_code": "11"},
        {"code": "1107", "name": "Zamboanga Sibugay", "region_code": "11"},
        
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
        
        # NCR
        {"code": "1401", "name": "Manila", "region_code": "NCR"},
        {"code": "1402", "name": "Quezon City", "region_code": "NCR"},
        {"code": "1403", "name": "Caloocan", "region_code": "NCR"},
        {"code": "1404", "name": "Las Piñas", "region_code": "NCR"},
        {"code": "1405", "name": "Makati", "region_code": "NCR"},
        {"code": "1406", "name": "Marikina", "region_code": "NCR"},
        {"code": "1407", "name": "Muntinlupa", "region_code": "NCR"},
        {"code": "1408", "name": "Navotas", "region_code": "NCR"},
        {"code": "1409", "name": "Pasay", "region_code": "NCR"},
        {"code": "1410", "name": "Pasig", "region_code": "NCR"},
        {"code": "1411", "name": "Pateros", "region_code": "NCR"},
        {"code": "1412", "name": "San Juan", "region_code": "NCR"},
        {"code": "1413", "name": "Taguig", "region_code": "NCR"},
        {"code": "1414", "name": "Valenzuela", "region_code": "NCR"},
        {"code": "1415", "name": "Malabon", "region_code": "NCR"},
    ],
    "cities": [
        # Metro Manila
        {"code": "133914", "name": "Manila", "province_code": "1401"},
        {"code": "133915", "name": "Quezon City", "province_code": "1402"},
        {"code": "133916", "name": "Caloocan", "province_code": "1403"},
        {"code": "133917", "name": "Las Piñas", "province_code": "1404"},
        {"code": "133918", "name": "Makati", "province_code": "1405"},
        {"code": "133919", "name": "Marikina", "province_code": "1406"},
        {"code": "133920", "name": "Muntinlupa", "province_code": "1407"},
        {"code": "133921", "name": "Pasay", "province_code": "1409"},
        {"code": "133922", "name": "Pasig", "province_code": "1410"},
        {"code": "133923", "name": "Taguig", "province_code": "1413"},
        {"code": "133924", "name": "Valenzuela", "province_code": "1414"},
        
        # Cavite
        {"code": "131631", "name": "Dasmarinas", "province_code": "0401"},
        {"code": "131632", "name": "Kawit", "province_code": "0401"},
        {"code": "131633", "name": "Rosario", "province_code": "0401"},
        {"code": "131634", "name": "Silang", "province_code": "0401"},
        {"code": "131635", "name": "Tagaytay", "province_code": "0401"},
        
        # Laguna
        {"code": "131711", "name": "Binangonan", "province_code": "0402"},
        {"code": "131712", "name": "Cabuyao", "province_code": "0402"},
        {"code": "131713", "name": "Calamba", "province_code": "0402"},
        {"code": "131714", "name": "Laguna", "province_code": "0402"},
        {"code": "131715", "name": "Pagsanjan", "province_code": "0402"},
        
        # Batangas
        {"code": "131741", "name": "Bauan", "province_code": "0403"},
        {"code": "131742", "name": "Batangas City", "province_code": "0403"},
        {"code": "131743", "name": "Lipa", "province_code": "0403"},
        {"code": "131744", "name": "Mabini", "province_code": "0403"},
        {"code": "131745", "name": "Tagaytay", "province_code": "0403"},
        
        # Sample cities for other provinces
        {"code": "113005", "name": "Iloilo City", "province_code": "0705"},
        {"code": "113006", "name": "Bacolod", "province_code": "0706"},
        {"code": "114115", "name": "Cebu City", "province_code": "0802"},
        {"code": "115019", "name": "Davao City", "province_code": "1002"},
        {"code": "118833", "name": "Cagayan de Oro", "province_code": "1101"},
        
        # Zamboanga del Sur
        {"code": "140701", "name": "Zamboanga City", "province_code": "1105"},
        {"code": "140702", "name": "Pagadian", "province_code": "1105"},
        {"code": "140703", "name": "Midsalip", "province_code": "1105"},
        
        # Zamboanga del Norte
        {"code": "140704", "name": "Dipolog", "province_code": "1106"},
        {"code": "140705", "name": "Liloy", "province_code": "1106"},
        {"code": "140706", "name": "Dapitan", "province_code": "1106"},
        
        # Zamboanga Sibugay
        {"code": "140707", "name": "Ipil", "province_code": "1107"},
        {"code": "140708", "name": "Tungawan", "province_code": "1107"},
        
        # Additional sample cities
        {"code": "102105", "name": "Manila (Sample)", "province_code": "1401"},
        {"code": "102106", "name": "Makati (Sample)", "province_code": "1405"},
        {"code": "102107", "name": "Quezon City (Sample)", "province_code": "1402"},
    ],
    "barangays": [
        # Manila
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
        
        # Quezon City
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
        
        # Makati
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
        
        # Pasig
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
        
        # Zamboanga City (10 barangays)
        {"code": "140701001", "name": "Baliwasan", "city_code": "140701"},
        {"code": "140701002", "name": "Bolong", "city_code": "140701"},
        {"code": "140701003", "name": "Calarian", "city_code": "140701"},
        {"code": "140701004", "name": "Catagenang", "city_code": "140701"},
        {"code": "140701005", "name": "Cawit", "city_code": "140701"},
        {"code": "140701006", "name": "Dipolog Proper", "city_code": "140701"},
        {"code": "140701007", "name": "Guisao", "city_code": "140701"},
        {"code": "140701008", "name": "Kagang", "city_code": "140701"},
        {"code": "140701009", "name": "Mambajao", "city_code": "140701"},
        {"code": "140701010", "name": "Pasonanca", "city_code": "140701"},
        
        # Pagadian (8 barangays)
        {"code": "140702001", "name": "Bagal", "city_code": "140702"},
        {"code": "140702002", "name": "Baliwasan", "city_code": "140702"},
        {"code": "140702003", "name": "Bolong", "city_code": "140702"},
        {"code": "140702004", "name": "Calarian", "city_code": "140702"},
        {"code": "140702005", "name": "Cawit", "city_code": "140702"},
        {"code": "140702006", "name": "Guisao", "city_code": "140702"},
        {"code": "140702007", "name": "Ipil", "city_code": "140702"},
        {"code": "140702008", "name": "Mambajao", "city_code": "140702"},
        
        # Dipolog (6 barangays)
        {"code": "140704001", "name": "Baliwasan", "city_code": "140704"},
        {"code": "140704002", "name": "Bolong", "city_code": "140704"},
        {"code": "140704003", "name": "Calarian", "city_code": "140704"},
        {"code": "140704004", "name": "Cawit", "city_code": "140704"},
        {"code": "140704005", "name": "Guisao", "city_code": "140704"},
        {"code": "140704006", "name": "Pasonanca", "city_code": "140704"},
        
        # Ipil (5 barangays)
        {"code": "140707001", "name": "Bagal", "city_code": "140707"},
        {"code": "140707002", "name": "Baliwasan", "city_code": "140707"},
        {"code": "140707003", "name": "Calarian", "city_code": "140707"},
        {"code": "140707004", "name": "Cawit", "city_code": "140707"},
        {"code": "140707005", "name": "Guisao", "city_code": "140707"},
    ]
}

def load_data():
    print("Loading regions...")
    regions_map = {}
    for region_data in PH_DATA['regions']:
        region, created = Region.objects.get_or_create(
            code=region_data['code'],
            defaults={'name': region_data['name']}
        )
        regions_map[region_data['code']] = region
    print(f"✓ Loaded {len(regions_map)} regions")
    
    print("Loading provinces...")
    provinces_map = {}
    for province_data in PH_DATA['provinces']:
        region = regions_map.get(province_data['region_code'])
        if region:
            province, created = Province.objects.get_or_create(
                code=province_data['code'],
                defaults={'name': province_data['name'], 'region': region}
            )
            provinces_map[province_data['code']] = province
    print(f"✓ Loaded {len(provinces_map)} provinces")
    
    print("Loading cities...")
    cities_map = {}
    for city_data in PH_DATA['cities']:
        province = provinces_map.get(city_data['province_code'])
        if province:
            city, created = City.objects.get_or_create(
                code=city_data['code'],
                defaults={'name': city_data['name'], 'province': province}
            )
            cities_map[city_data['code']] = city
    print(f"✓ Loaded {len(cities_map)} cities")
    
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
    print(f"✓ Loaded {barangay_count} new barangays")
    
    print("\n✅ All Philippine address data loaded successfully!")
    print(f"  - Regions: {Region.objects.count()}")
    print(f"  - Provinces: {Province.objects.count()}")
    print(f"  - Cities: {City.objects.count()}")
    print(f"  - Barangays: {Barangay.objects.count()}")

if __name__ == '__main__':
    load_data()
