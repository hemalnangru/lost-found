# Pan-India Lost & Found AI Matching Platform

A web portal where people report lost or found belongings. The system compares
reports using AI and suggests likely matches, with a percentage score and the
reasons behind it ("400 m away", "same colour", "1 day apart").

Course project for INT252, Lovely Professional University.
Team: Astha Dixit, Hemal Nangru, Shubham Kumar.

![Match results](docs/matches.png)

## Features

- Report lost or found items with category, colour, city, date and a photo
- Click a map to drop a pin (Leaflet and OpenStreetMap)
- AI text matching with sentence embeddings and pgvector
- Score breakdown that explains why two items match
- Secure claim flow: the finder sets a hidden question, and the owner must
  answer it before the finder's contact is shown
- Email and password login, and a My reports page with status tracking
- Browse page with filters for type, category and city
- Demo data script and an accuracy test script

## How matching works

1. Hard filters first: same category, status open, and found date on or after
   the lost date.
2. The title, description and colour are turned into a 384-number embedding
   with `all-MiniLM-L6-v2`, run locally with Transformers.js.
3. Candidates are ranked by cosine similarity using pgvector.
4. The final score combines three signals:

   `score = 0.6 x text similarity + 0.2 x location + 0.2 x date closeness`

   Location is 1 at the same spot and falls to 0 at 20 km (haversine
   distance). If a report has no map pin, the same city counts instead.
   Date closeness falls to 0 at 30 days apart.

## Security

- Row-level security: anyone can read items, but only logged-in users can
  create them, and only as themselves. Only owners can update or delete.
- Claim answers and contact details live in a separate locked table
  (`item_secrets`) with no read policy. A database function checks the
  answer and only then returns the contact, so secrets never reach the browser.

## Evaluation

Tested on 20 self-written lost/found pairs, where each pair describes the same
item in different words. Each lost item was matched against all open found
items in its category.

| Method                     | Top-1 | Top-3 | Top-5 |
|----------------------------|-------|-------|-------|
| Text meaning only          | 100%  | 100%  | 100%  |
| Combined (text+place+date) | 100%  | 100%  | 100%  |

Tested on 21 lost items against all open found items in the same category.
The pairs were written by us, and each category has only a few found items,
so this is an easy benchmark. Both methods reach 100%, so this test cannot
show whether location and date improve ranking. A harder test with more
similar items per category, and real reports, is future work.