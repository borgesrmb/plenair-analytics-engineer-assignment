#!/usr/bin/env python3

from collections import Counter

def main():
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
    
if __name__ == "__main__":
    main()

