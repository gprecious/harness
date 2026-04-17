def handle_request(req):
    # 40+ line method doing validation, DB, business logic, response in one place
    if not req:
        return {"status": "error", "msg": "no request"}
    if "user_id" not in req:
        return {"status": "error", "msg": "no user_id"}
    user_id = req["user_id"]
    if not isinstance(user_id, int):
        return {"status": "error", "msg": "user_id must be int"}
    if user_id < 0:
        return {"status": "error", "msg": "negative"}
    action = req.get("action")
    if action not in ["create", "update", "delete"]:
        return {"status": "error", "msg": "bad action"}
    if action == "create":
        data = req.get("data", {})
        if not data:
            return {"status": "error", "msg": "no data"}
        if "name" not in data:
            return {"status": "error", "msg": "no name"}
        name = data["name"]
        if len(name) > 100:
            return {"status": "error", "msg": "name too long"}
        print(f"creating {name}")
        return {"status": "ok"}
    elif action == "update":
        if "id" not in req:
            return {"status": "error", "msg": "no id for update"}
        print(f"updating {req['id']}")
        return {"status": "ok"}
    else:
        if "id" not in req:
            return {"status": "error", "msg": "no id for delete"}
        print(f"deleting {req['id']}")
        return {"status": "ok"}
