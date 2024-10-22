import requests
import random
import boto3
from botocore.exceptions import ClientError

# Connect to DynamoDB
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('PokemonData')

# Function to fetch a list of Pokémon from the API
def fetch_pokemon(limit=5):
    # Set random offset to avoid getting the same Pokémon every time
    url = f"https://pokeapi.co/api/v2/pokemon?limit={limit}&offset={random.randint(0, 1010 - limit)}"
    response = requests.get(url)
    # Return the list of Pokémon if the request was successful
    return response.json()['results'] if response.status_code == 200 else []

# Function to check if a Pokémon exists in DynamoDB
def check_pokemon_in_db(pokemon_name):
    try:
        # Get the Pokémon by its name (primary key)
        item = table.get_item(Key={'name': pokemon_name}).get('Item')
        # Return True if the Pokémon exists, False otherwise
        return (True, item) if item else (False, None)
    except ClientError as e:
        print(f"Error: {e.response['Error']['Message']}")
        return False, None

# Function to save Pokémon details to DynamoDB
def save_pokemon_to_db(pokemon):
    try:
        # Insert the Pokémon data into the DynamoDB table
        table.put_item(Item=pokemon)
    except ClientError as e:
        print(f"Error: {e.response['Error']['Message']}")

# Main game function
def main():
    while input("\nDraw a Pokémon? (Y/N): ").strip().upper() == "Y":
        # Fetch a list of Pokémon
        pokemon_list = fetch_pokemon()
        if not pokemon_list: continue
        # Randomly choose a Pokémon and get its details
        pokemon = random.choice([requests.get(p['url']).json() for p in pokemon_list])
        
        # Check if the Pokémon already exists in DynamoDB
        exists, p_data = check_pokemon_in_db(pokemon['name'])
        if exists:
            print(f"{pokemon['name']} already exists.")
        else:
            # Save the new Pokémon to the database
            save_pokemon_to_db({
                'name': pokemon['name'], 
                'height': pokemon['height'], 
                'weight': pokemon['weight']
            })
            print(f"Saved {pokemon['name']}.")

if __name__ == "__main__":
    main()
