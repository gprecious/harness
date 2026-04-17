def classify(user, plan, country, age, is_admin, flags):
    if user is not None:
        if plan == "pro":
            if country == "US":
                if age >= 18:
                    if is_admin:
                        return "pro-us-admin"
                    else:
                        if "beta" in flags:
                            return "pro-us-beta"
                        else:
                            return "pro-us"
                else:
                    return "pro-us-minor"
            else:
                if age >= 18:
                    return "pro-intl"
                else:
                    return "pro-intl-minor"
        elif plan == "free":
            if country == "US":
                return "free-us" if age >= 18 else "free-us-minor"
            else:
                return "free-intl"
    return "anonymous"
