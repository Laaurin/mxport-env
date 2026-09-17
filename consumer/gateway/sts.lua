-- Consumer-Gateway STS module
-- Adapted from the original sts.lua (mxport-leo-gateway/openresty-sts-module/docker/sts.lua)
--
-- Change from the original: the "audience" parameter is NOT sent to the STS,
-- because the core token-exchange-core filters do not support the audience
-- request parameter (see STS README "Limitations").
-- The target_service value is still used as the cache key for isolation.
--
-- Copyright 2026 Codewerk GmbH – Apache 2.0

local _M = {}

local http  = require("resty.http")
local cjson = require("cjson")

function _M.exchange(opts)
  opts = opts or {}

  local sts_url = opts.sts_url
  if not sts_url then
    ngx.log(ngx.ERR, "sts.exchange: sts_url is required")
    ngx.exit(500)
  end

  local target_service = opts.target_service
  if not target_service then
    ngx.log(ngx.ERR, "sts.exchange: target_service is required")
    ngx.exit(500)
  end

  local cache_name  = opts.cache_name  or "sts_token_cache"
  local default_ttl = opts.default_ttl or 300

  local auth = ngx.req.get_headers()["Authorization"]
  if not auth then
    return    -- no Authorization header → passthrough
  end

  local source_token = string.match(auth, "^[Bb]earer%s+(.+)$")
  if not source_token then return end

  -- Cache lookup – key includes target_service for caller isolation
  local cache = ngx.shared[cache_name]
  local cache_key = target_service .. ":" .. source_token
  local target_token = cache:get(cache_key)

  if not target_token then
    local httpc = http.new()
    ngx.log(ngx.INFO, "sts.exchange: requesting token from ", sts_url,
      " grant_type=", "urn:ietf:params:oauth:grant-type:token-exchange",
      " subject_token_type=", "urn:ietf:params:oauth:token-type:jwt",
      " (no audience – not supported by token-exchange-core filters)")

    -- NOTE: "audience" is intentionally omitted here.
    -- The token-exchange-core library does not support the audience request
    -- parameter in its built-in filters. Sending it would cause the STS to
    -- return a 400 "Expiry of issued token would be null" error.
    local res, err = httpc:request_uri(sts_url, {
      method  = "POST",
      headers = { ["Content-Type"] = "application/x-www-form-urlencoded" },
      body    = "grant_type="
        .. ngx.escape_uri("urn:ietf:params:oauth:grant-type:token-exchange")
        .. "&subject_token_type="
        .. ngx.escape_uri("urn:ietf:params:oauth:token-type:jwt")
        .. "&subject_token=" .. ngx.escape_uri(source_token),
    })

    if not res then
      ngx.status = 502
      ngx.exit(502)
    elseif res.status ~= 200 then
      local status = (res.status >= 400 and res.status < 500) and 401 or 502
      ngx.status = status
      ngx.exit(status)
    end

    local data = cjson.decode(res.body)
    target_token = data.access_token
    cache:set(cache_key, target_token, tonumber(data.expires_in) or default_ttl)
  end

  ngx.req.set_header("Authorization", "Bearer " .. target_token)
end

return _M
