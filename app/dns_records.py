from typing import Dict, List
import json
from urllib.parse import urlencode



def from_json(input : str) -> List[Dict]:
    """Loads dns-records from json"""
    return json.loads(input)




def to_form_url_encoded(records : List[Dict]) -> str:
    """Converts dns-records to 'form url-encoded'. This format is used to update the dns-records on 1blu."""
    params = []
    for record in records:
        for key in record.keys():
            params.append((f"records[{record['id']}][{key}]", record[key]))
    return urlencode(params)
