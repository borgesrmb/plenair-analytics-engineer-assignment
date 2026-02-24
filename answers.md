# Plein Air: Analytics Engineer Technical Assessment
**Candidate:** Ricardo Borges

---

## Part 1: Core Metrics (SQL)

### Query

```sql
-- Part 1: Per-location metrics for March 2023
-- Two versions: raw (all rows) and clean (excluding anomalies).

-- RAW: includes $0 and negative amounts to show what actually exists
SELECT
    l.location_id,
    l.location_name,
    l.city,
    SUM(o.order_amount) AS total_revenue,
    COUNT(o.order_id) AS total_orders,
    ROUND(AVG(o.order_amount), 2) AS avg_order_value
FROM
    orders o
JOIN
    locations l
    ON o.location_id = l.location_id
WHERE
    o.order_date BETWEEN '2023-03-01' AND '2023-03-31'
GROUP BY
    location_id,
    location_name,
    city
ORDER BY
    total_revenue DESC;

-- CLEAN: excludes zero and negative amounts (see Q1 below for rationale)
SELECT
    l.location_id,
    l.location_name,
    l.city,
    SUM(o.order_amount) AS total_revenue,
    COUNT(o.order_id) AS total_orders,
    ROUND(AVG(o.order_amount), 2) AS avg_order_value
FROM
    orders o
JOIN
    locations l
    ON o.location_id = l.location_id
WHERE
    o.order_date BETWEEN '2023-03-01' AND '2023-03-31'
    AND o.order_amount > 0
GROUP BY
    location_id,
    location_name,
    city
ORDER BY
    total_revenue DESC;
```

### Expected Results

**Raw (all orders):**

| location_id | location_name | city   | total_revenue | total_orders | avg_order_value |
|-------------|---------------|--------|---------------|--------------|-----------------|
| 1           | Downtown      | Dallas | 80.50         | 4            | 20.13           |
| 2           | Uptown        | Dallas | 49.50         | 2            | 24.75           |
| 3           | Midtown       | Austin | 0.00          | 2            | 0.00            |

**Clean (order_amount > 0):**

| location_id | location_name | city   | total_revenue | total_orders | avg_order_value |
|-------------|---------------|--------|---------------|--------------|-----------------|
| 1           | Downtown      | Dallas | 80.50         | 3            | 26.83           |
| 2           | Uptown        | Dallas | 49.50         | 2            | 24.75           |
| 3           | Midtown       | Austin | 45.00         | 1            | 45.00           |

---

### Q1: Data issues affecting revenue or AOV

There are a couple of records in the orders table that would mess up revenue and AOV if we just take the data at face value.

1. **Order 1008: -$45.00 (customer 103, location 3, 2023-03-25)**:
- This looks like a refund (or a void) for order 1004, which was $45.00 (same customer, same location). If we keep both rows in the calculation, Location 3 ends up with $0.00 revenue and $0.00 AOV, which obviously doesn't reflect what actually happened. It also makes it look like there were two visits, when in practice it was one sale that later got reversed.

2. **Order 1007: $0.00 (customer 105, location 1, 2023-03-19)**:
- A $0 order could be a comped meal, a test transaction, or just a mistake. It doesn't change total revenue, but it does inflate the order count, which pulls AOV down (from $26.83 to $20.13 for Downtown if you include it). So even though revenue stays the same, the performance metrics get distorted.

### Q2: How to handle in production

A few options for handling this in production:
- Add an `order_type` column ('sale', 'refund', 'void', 'comp') at ingestion. Revenue metrics filter to `order_type = 'sale'`; refunds are tracked separately as `net_revenue = gross_revenue - refunds`.
- Add tests via dbt:
    - `not_null` on `order_amount`, a custom `accepted_range` test requiring `order_amount >= 0` for sales, and a `relationships` test between orders and customers/locations.
    - Warnings fire when negative amounts appear unexpectedly, giving the data team time to investigate before metrics reach downstream dashboards.

---

## Part 2: Loyalty & Customer Behavior (SQL)

### Assumption

Orders with `order_amount <= 0` are excluded from this analysis. Specifically, order 1007 ($0.00) and order 1008 (-$45.00) are treated as non-sales (test transactions or reversals). This is consistent with the logic established in Part 1 and ensures the metrics are comparable across sections.

---

### Query

```sql
-- Part 2: Loyalty vs Non-member Comparison (March 2023, order_amount > 0)
WITH
march_orders AS (
    SELECT
        o.order_id,
        o.customer_id,
        o.order_amount,
        c.loyalty_member
    FROM
        orders o
    JOIN
        customers c
        ON o.customer_id = c.customer_id
    WHERE
        o.order_date BETWEEN '2023-03-01' AND '2023-03-31'
        AND o.order_amount > 0
),
per_customer AS (
    SELECT
        customer_id,
        loyalty_member,
        COUNT(*) AS order_count,
        SUM(order_amount) AS total_spent
    FROM
        march_orders
    GROUP BY
        customer_id,
        loyalty_member
)
SELECT
    loyalty_member,
    SUM(order_count) AS total_orders,
    COUNT(customer_id) AS distinct_customers,
    ROUND(SUM(total_spent) / SUM(order_count), 2) AS avg_order_value,
    ROUND(SUM(order_count) / COUNT(customer_id), 2) AS orders_per_customer,
    ROUND(
        SUM(CASE WHEN order_count > 1 THEN 1 ELSE 0 END)
        / NULLIF(COUNT(customer_id), 0),
        2
    ) AS repeat_rate
FROM
    per_customer
GROUP BY
    loyalty_member;
```

---

### Expected Results

| loyalty_member | total_orders | distinct_customers | avg_order_value | orders_per_customer | repeat_rate |
|----------------|--------------|-------------------|-----------------|---------------------|-------------|
| true           | 4            | 2                 | 33.63           | 2.00                | 0.50        |
| false          | 2            | 2                 | 20.25           | 1.00                | 0.00        |

---

### Note on Customer 105

Customer 105 is enrolled in the loyalty program, but their only March order (1007) was $0.00 and is excluded from this analysis. As a result, they do not appear in the `distinct_customers` count for the loyalty segment. This is intentional: the comparison focuses on customers who generated valid revenue during the period, not on total program enrollment.

---

### Assumptions Made

- Orders with `order_amount <= 0` are excluded, consistent with Part 1.
- Only customers who placed at least one valid order in March are included. The repeat rate therefore measures, among active customers in the period, how many placed more than one order.
- No order_id deduplication was required. Although the Python dataset contained a duplicate `order_id` (1006), the SQL sample does not reflect this duplication, so no deduplication step is needed here.

---

### Limitations

- The dataset is too small for statistically meaningful conclusions. There are 3 loyalty members and 2 non-members overall, and only 2 loyalty members generated valid purchases. Differences like $33.63 vs $20.25 in AOV may reflect normal variance rather than any real behavioral pattern.
- A few additional caveats: Customer 105 (loyalty) had no valid purchases in the period; Customer 103 (loyalty) had a $45 order fully reversed; and the analysis covers a single month.
- Loyalty behavior typically plays out over longer periods, and cross-month repeat behavior is not captured here.
- In production, reliable conclusions would require a much larger customer base and a longer time horizon.

---

## Part 3: Campaign Effectiveness & Attribution (SQL)

### Query

```sql
-- Part 3 · Campaign Effectiveness.
-- Keeping the first redemption_id for multiple redemptions per order to avoid double-counting revenue.
WITH
deduped_redemptions AS (
    SELECT
        campaign_name,
        order_id,
        MIN(redemption_id) AS redemption_id
    FROM
        campaign_redemptions
    GROUP BY
        campaign_name,
        order_id
),
raw_counts AS (
    SELECT
        campaign_name,
        COUNT(redemption_id) AS raw_redemption_count,
        COUNT(DISTINCT order_id) AS clean_redemption_count
    FROM
        campaign_redemptions
    GROUP BY
        campaign_name
)
SELECT
    dr.campaign_name,
    rc.raw_redemption_count,
    rc.clean_redemption_count,
    SUM(o.order_amount) AS total_revenue,
    ROUND(AVG(o.order_amount), 2) AS avg_order_value
FROM
    deduped_redemptions dr
JOIN
    orders o
    ON dr.order_id = o.order_id
JOIN
    raw_counts rc
    ON dr.campaign_name = rc.campaign_name
GROUP BY
    campaign_name,
    raw_redemption_count,
    clean_redemption_count;
```

---

### Expected Results

| campaign_name   | raw_redemption_count | clean_redemption_count | total_revenue | avg_order_value |
|-----------------|----------------------|------------------------|---------------|-----------------|
| Loyalty Welcome | 1                    | 1                      | 45.00         | 45.00           |
| Spring Promo    | 3                    | 2                      | 57.00         | 28.50           |

---

### Q1: Data Quality Risks

1. Order 1006 appears twice in `campaign_redemptions` (IDs 203 and 204) for the same campaign. Without deduplication, revenue and redemption counts would be overstated.
2. Order 1008 (-$45.00) reverses order 1004, which was attributed to "Loyalty Welcome." The redemptions table does not capture this reversal, so campaign revenue ends up overstated.
3. There is no constraint enforcing that each redemption maps to a valid order, or that an order cannot be linked to multiple campaigns.
4. Since `campaign_redemptions` does not include `customer_id`, attribution relies entirely on the integrity of the orders table.

---

### Q2: Can We Conclude Which Campaign Is Better?

No. We have no exposure data (how many customers received each campaign), no control group to estimate incremental impact, refunds distort attributed revenue, the sample is extremely small, and campaign costs are unknown. Any comparison drawn from this data alone would be incomplete and potentially misleading.

---

### Q3: Additional Data Needed Before Presenting to a Client

Before sharing these results with a client, we would need:
- Clear revenue definitions: gross vs. net, how refunds and voids are recorded, and what qualifies as a valid purchase.
- Campaign exposure data: how many customers received each campaign, and how treatment/control assignment was handled.
- A pre-campaign baseline window to measure lift rather than just absolute revenue differences.
- Data quality checks covering late-arriving transactions and any bias introduced by joins or filters.

---

## Part 4: Data Modeling Thinking

### 1. Grain of the `orders` Table

One row per individual order event, uniquely identified by `order_id`. Given the presence of negative transactions (e.g., order 1008), the grain should be explicitly defined as "one row per order event," with an `order_type` field (e.g., sale, refund, void) to eliminate ambiguity.

---

### 2. Facts vs Dimensions

| Table                   | Type      | Rationale                                                      |
|-------------------------|-----------|----------------------------------------------------------------|
| `orders`                | Fact      | Transaction-level data with additive measures and foreign keys |
| `campaign_redemptions`  | Fact      | Event-level data capturing campaign usage                      |
| `customers`             | Dimension | Descriptive attributes, relatively low cardinality             |
| `locations`             | Dimension | Stable descriptive attributes                                  |

Facts represent business events (orders, redemptions, transactions). Dimensions provide the context that describes them.

---

### 3. Should `campaign_redemptions` Be Separate?

Yes, it should remain a separate fact table.
- The data shows the relationship is not strictly one-to-one: order 1006 has two redemption rows.
- Embedding campaign data directly in `orders` would introduce duplication and limit flexibility for future modeling.
- A separate redemption fact preserves attribution history and supports more advanced approaches like multi-touch attribution.

---

### 4. dbt Tests (Model-Level)

#### `stg_orders`

```yaml
models:
  - name: stg_orders
    columns:
      - name: order_id
        tests: [unique, not_null]
      - name: customer_id
        tests: [not_null, relationships: {to: ref('stg_customers'), field: customer_id}]
      - name: location_id
        tests: [not_null, relationships: {to: ref('stg_locations'), field: location_id}]
      - name: order_date
        tests: [not_null]
      - name: order_amount
        tests:
          - not_null
          - dbt_utils.expression_is_true:
                expression: "order_amount > 0"
```

#### `stg_campaign_redemptions`

```yaml
models:
  - name: stg_campaign_redemptions
    columns:
      - name: redemption_id
        tests: [unique, not_null]
      - name: order_id
        tests:
          - not_null
          - relationships: {to: ref('stg_orders'), field: order_id}
      - name: campaign_name
        tests: [not_null]
      - name: redeemed_date
        tests: [not_null]
```

#### `stg_customers`

```yaml
models:
  - name: stg_customers
    columns:
      - name: customer_id
        tests: [unique, not_null]
      - name: loyalty_member
        tests:
          - accepted_values: {values: [true, false]}
```

---

## Part 5 – Python: Data Quality & Debugging

### Code

```python
from collections import Counter

orders_data = [
    {"order_id": 1001, "customer_id": 101, "order_amount": 32.50},
    {"order_id": 1002, "customer_id": 102, "order_amount": 18.00},
    {"order_id": 1003, "customer_id": 101, "order_amount": 27.00},
    {"order_id": 1004, "customer_id": 103, "order_amount": 45.00},
    {"order_id": 1005, "customer_id": 104, "order_amount": 22.50},
    {"order_id": 1006, "customer_id": 101, "order_amount": 30.00},
    {"order_id": 1006, "customer_id": 101, "order_amount": 30.00},
    {"order_id": 1007, "customer_id": 105, "order_amount": 0.00},
    {"order_id": 1008, "customer_id": 103, "order_amount": -45.00},
]

# 1. Detect duplicate order_ids
order_id_counts = Counter(o["order_id"] for o in orders_data)
duplicate_ids = {oid for oid, count in order_id_counts.items() if count > 1}

print("\n=== Duplicates ===")
if duplicate_ids:
    for o in orders_data:
        if o["order_id"] in duplicate_ids:
            print(f"  DUPLICATE  order_id={o['order_id']}  amount={o['order_amount']}")
else:
    print("None found.")

# 2. Identify zero or negative amounts
invalid_amount_orders = [o for o in orders_data if o["order_amount"] <= 0]

print("\n=== Zero / Negative Amounts ===")
if invalid_amount_orders:
    for o in invalid_amount_orders:
        flag = "NEGATIVE" if o["order_amount"] < 0 else "ZERO"
        print(f"  {flag}  order_id={o['order_id']}  amount={o['order_amount']}")
else:
    print("None found.")

# 3. Compute total valid revenue
# Skip duplicate order_ids (keep first) and orders where amount <= 0.
seen_ids = set()
valid_orders, skipped_orders = [], []

for order in orders_data:
    oid = order["order_id"]
    if oid in seen_ids:
        skipped_orders.append((order, "duplicate"))
        continue

    seen_ids.add(oid)
    if order["order_amount"] <= 0:
        skipped_orders.append(
            (order, "negative" if order["order_amount"] < 0 else "zero_amount")
        )
    else:
        valid_orders.append(order)

total_valid_revenue = sum(o["order_amount"] for o in valid_orders)

print("\n=== Valid Orders ===")
for o in valid_orders:
    print(f"order_id={o['order_id']}  customer_id={o['customer_id']}  amount={o['order_amount']:.2f}")

print("\n=== Skipped Orders ===")
for o, reason in skipped_orders:
    print(f"SKIPPED ({reason})  order_id={o['order_id']}  amount={o['order_amount']:.2f}")

print(f"\n=== Total Valid Revenue: ${total_valid_revenue:.2f} ===")
```

### Expected Output

```
=== Duplicates ===
  DUPLICATE  order_id=1006  amount=30.0
  DUPLICATE  order_id=1006  amount=30.0

=== Zero / Negative Amounts ===
  ZERO      order_id=1007  amount=0.0
  NEGATIVE  order_id=1008  amount=-45.0

=== Valid Orders ===
  order_id=1001  customer_id=101  amount=32.50
  order_id=1002  customer_id=102  amount=18.00
  order_id=1003  customer_id=101  amount=27.00
  order_id=1004  customer_id=103  amount=45.00
  order_id=1005  customer_id=104  amount=22.50
  order_id=1006  customer_id=101  amount=30.00

=== Skipped Orders ===
  SKIPPED (duplicate)     order_id=1006  amount=30.00
  SKIPPED (zero_amount)   order_id=1007  amount=0.00
  SKIPPED (negative)      order_id=1008  amount=-45.00

=== Total Valid Revenue: $175.00 ===
```

---

### Assumptions Made

- For a duplicate `order_id`, the first occurrence is kept. In a real pipeline, deduplication should happen upstream using a deterministic key (e.g., `MIN(created_at)` or `MAX(updated_at)` in SQL) rather than relying on list order. All duplicates are flagged so the team can investigate the source.
- Zero-amount orders are excluded from revenue. They could represent comped meals, but without an `order_type` or `discount_type` field there is no way to distinguish them from errors. They are flagged separately from negatives so each case can be reviewed on its own.
- Negative amounts are treated as refunds or voids and excluded from gross revenue. These are not simply bad data since they may represent legitimate reversals, but they belong in a separate refunds model, not in revenue aggregations.
- The duplicate row is dropped entirely rather than averaged or reconciled, since both occurrences have identical amounts and the root cause is unknown.

### How to Productionize This Validation

**In dbt (preferred for a warehouse-native stack):**
```yaml
# schema.yml
- name: order_id
  tests:
    - unique
    - not_null
- name: order_amount
  tests:
    - dbt_utils.expression_is_true:
         expression: "order_amount > 0"
```
A separate `stg_orders_flagged` model can capture anomalous rows for audit without blocking the main pipeline.

**Logging best practice:**
```python
import logging
logger = logging.getLogger(__name__)

logger.warning(
    "Data quality issue detected",
    extra={
        "duplicate_order_ids": list(duplicate_ids),
        "invalid_amount_order_ids": [o["order_id"] for o in invalid_amount_orders],
        "skipped_count": len(skipped_orders),
        "valid_revenue": total_valid_revenue,
    }
)
```
Structured logging (JSON) allows downstream monitoring tools like Datadog to alert on anomaly thresholds automatically.

