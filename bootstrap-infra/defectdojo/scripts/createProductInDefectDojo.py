#!/usr/bin/env python
#TODO :
# - Changer la premiere ligne pour que ca marche dans docker
# - Rendre paramètrable le script (adresse, api_key, user, ET AUSSI project id, nom du projet...)
# - Faire l'algo suivant : lister les produits existants, si le produit id voulu (1 ?) n'existe pas, creer un produit avec le nom du projet

# import the package
from defectdojo_api import defectdojo
from datetime import datetime, timedelta


# setup DefectDojo connection information
host = 'http://localhost:8000'
api_key = 'f0c2e20880588064820020ab658f32f301611397'
user = 'admin'

# instantiate the DefectDojo api wrapper
dd = defectdojo.DefectDojoAPI(host, api_key, user, 'v1', False, debug=False)

# If you need to disable certificate verification, set verify_ssl to False.
# dd = defectdojo.DefectDojoAPI(host, api_key, user, verify_ssl=False)

# Create a product
prod_type = 1 #1 - Research and Development, product type

product = dd.create_product("New 1", "This is a detailed product description.", prod_type)

if product.success:
    # Get the product id
    product_id = product.id()
    print "Product successfully created with an id: " + str(product_id)
"""
start_date = datetime.now()
end_date = start_date+timedelta(days=1)
engagement_id = dd.create_engagement("blabal", 1, 1,
                                     "In Progress", start_date.strftime("%Y-%m-%d"), end_date.strftime("%Y-%m-%d"))

print engagement_id
"""
#List Products
products = dd.list_products()

if products.success:
    #print(products.data_json(pretty=True))  # Decoded JSON object

    for product in products.data["objects"]:
        print(product['name'] + " " + str(product['id']))  # Print the name of each product
else:
    print products.message
