# Olist Brazilian E-Commerce Analysis
**PostgreSQL · Power BI · 96,478 Orders · 9 Relational Tables**

---

## Business Problem
Olist is a Brazilian marketplace connecting small sellers to major retail 
channels. Unlike direct retailers, Olist's reputation depends entirely on 
third-party seller quality — a seller who ships late damages Olist's brand, 
not just their own.

This analysis uses 25 months of real transaction data (Sep 2016 – Aug 2018) 
to answer three questions:
- Which categories, sellers, and states drive platform revenue?
- How does delivery performance affect customer satisfaction?
- Which sellers are healthy, which need monitoring, which should be removed?

---

## Key Findings

| Metric | Value |
|--------|-------|
| Total GMV | BRL 13,591,643 |
| Avg Order Value | BRL 137.75 |
| Delivered Orders | 96,478 |
| On-Time Delivery Rate | 91.89% |
| Top 10% sellers — revenue share | 67.11% |
| Black Friday MoM spike (Nov 2017) | +52.37% |
| Revenue growth Jan 2017 → Apr 2018 | 8.7× |
| Repeat customer rate | 3.00% |
| Loyal customer LTV vs single-purchase | 3.1× higher |

**The standout finding — delivery delay destroys review scores:**

| Delivery Status | Avg Review | Negative Review % |
|----------------|-----------|-------------------|
| 7+ days early | 4.32 | 8.98% |
| On time | 4.20 | 10.27% |
| Up to 7 days late | 3.18 | 36.07% |
| 7+ days late | **1.73** | **78.33%** |

A 7+ day delivery breach drops the average review score by 2.59 points 
and pushes negative reviews from 9% to 78%. Delivery reliability is a 
brand metric, not just a logistics metric.

**Seller health scoring — 1,237 qualified sellers (10+ orders):**

| Status | Sellers | Avg Late % | Revenue |
|--------|---------|-----------|---------|
| Green | 655 | 4.13% | BRL 6.2M |
| Yellow | 478 | 10.98% | BRL 5.2M |
| Red | 104 | **28.32%** | BRL 0.6M |

---

## Business Recommendations
1. **Investigate 104 Red sellers** — 28.32% late rate actively damages 
   platform reviews. They generate only 5% of GMV. Introduce SLA 
   enforcement or delist chronic offenders.
2. **Protect top 124 sellers** — top 10% of sellers generate 67.11% of 
   GMV. These accounts need dedicated account management.
3. **Build a repeat-purchase programme** — repeat rate is only 3%, but 
   customers who return spend 3.1× more in lifetime value. Retention 
   offers should target lower-ticket follow-up products — repeat buyers 
   average BRL 80 per order vs BRL 130 for first-time buyers.
4. **Pre-position logistics for November** — Black Friday caused a +52.37% 
   MoM revenue spike. Seasonal scaling should be planned ahead of Q4.

---

## Database Schema
9 tables, 6 foreign key relationships, built in PostgreSQL.

customers (99,441)
orders (99,441)
order_items (112,650)
products (32,951)
product_category_translation (71)
sellers (3,095)
order_payments (103,886)
order_reviews (99,224)

**Data quality issues found and handled:**
- Products table CSV has a typo: `product_name_lenght` — schema matched 
  the typo to allow clean import
- order_reviews has 814 duplicate review_ids in source data — no PK added, 
  handled with `DISTINCT ON` in queries
- 13 products have category names missing from the translation table — 
  handled with LEFT JOIN, not INNER JOIN, so these products remain in analysis
- Delivery-related NULL dates (cancelled/undelivered orders) are legitimate 
  business states, not missing data — not filled


## Tools
- **PostgreSQL** — schema design, FK constraints, all analytical queries
- **pgAdmin 4** — query execution and data export
- **Power BI** — data model, DAX measures, 3-page dashboard
- **Dataset** — [Brazilian E-Commerce Public Dataset by Olist]
  (https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce)
