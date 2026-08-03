import unittest
from app import dns_records


class TestDnsRecords(unittest.TestCase):


    def test_from_json(self):
        json = '''[
            {"id": 0,"hostname": "@","type": "A","target": "123.123.123.123"},
            {"id": 1,"hostname": "www","type": "A","target": "123.456.789.10"},
            {"id": 2,"hostname": "mail","type": "A","target": "123.123.234.234"},
            {"id": 3,"hostname": "@","type": "MX","target": "mail.example.de","prio": "10"},
            {"id": 4,"hostname": "example.de","type": "TXT","target": "text"},
            {"id": 5,"hostname": "abc","type": "A","target": "78.78.78.80"}]'''

        records = dns_records.from_json(json)
        self.assertIsNotNone(records)
        self.assertIs(type(records), list)

        self.assertEqual(len(records),6)
        self.assertIs(type(records[0]), dict)
        self.assertDictEqual(records[0], {"id": 0,"hostname": "@","type": "A","target": "123.123.123.123"})
        self.assertIs(type(records[1]), dict)
        self.assertDictEqual(records[1], {"id": 1,"hostname": "www","type": "A","target": "123.456.789.10"})
        self.assertIs(type(records[2]), dict)
        self.assertDictEqual(records[2], {"id": 2,"hostname": "mail","type": "A","target": "123.123.234.234"})
        self.assertIs(type(records[3]), dict)
        self.assertDictEqual(records[3], {"id": 3,"hostname": "@","type": "MX","target": "mail.example.de","prio": "10"})
        self.assertIs(type(records[4]), dict)
        self.assertDictEqual(records[4], {"id": 4,"hostname": "example.de","type": "TXT","target": "text"})
        self.assertIs(type(records[5]), dict)
        self.assertDictEqual(records[5], {"id": 5,"hostname": "abc","type": "A","target": "78.78.78.80"})

 
    def test_to_form_url_encoded(self):
        records = [
            {"id": 0,"hostname": "@","type": "A","target": "123.123.123.123"},
            {"id": 1,"hostname": "www","type": "A","target": "123.456.789.10"},
            {"id": 2,"hostname": "mail","type": "A","target": "123.123.234.234"},
            {"id": 3,"hostname": "@","type": "MX","target": "mail.example.de","prio": "10"},
            {"id": 4,"hostname": "example.de","type": "TXT","target": "text"},
            {"id": 5,"hostname": "abc","type": "A","target": "78.78.78.80"}]

        self.assertEqual(dns_records.to_form_url_encoded(records), (
            'records%5B0%5D%5Bid%5D=0&records%5B0%5D%5Bhostname%5D=%40&records%5B0%5D%5Btype%5D=A&records%5B0%5D%5Btarget%5D=123.123.123.123&'
            'records%5B1%5D%5Bid%5D=1&records%5B1%5D%5Bhostname%5D=www&records%5B1%5D%5Btype%5D=A&records%5B1%5D%5Btarget%5D=123.456.789.10&'
            'records%5B2%5D%5Bid%5D=2&records%5B2%5D%5Bhostname%5D=mail&records%5B2%5D%5Btype%5D=A&records%5B2%5D%5Btarget%5D=123.123.234.234&'
            'records%5B3%5D%5Bid%5D=3&records%5B3%5D%5Bhostname%5D=%40&records%5B3%5D%5Btype%5D=MX&records%5B3%5D%5Btarget%5D=mail.example.de&records%5B3%5D%5Bprio%5D=10&'
            'records%5B4%5D%5Bid%5D=4&records%5B4%5D%5Bhostname%5D=example.de&records%5B4%5D%5Btype%5D=TXT&records%5B4%5D%5Btarget%5D=text&'
            'records%5B5%5D%5Bid%5D=5&records%5B5%5D%5Bhostname%5D=abc&records%5B5%5D%5Btype%5D=A&records%5B5%5D%5Btarget%5D=78.78.78.80'))

if __name__ == '__main__':
    unittest.main()
