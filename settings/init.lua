-- WiFi IP 자동 전환 스크립트 (디버그 버전)
-- 네트워크 서비스 이름 (필요시 변경)
local SERVICE = "Wi-Fi"

-- 디버그 모드 (true로 설정하면 상세 로그 출력)
local DEBUG = true

-- 로그 파일 경로
local LOG_FILE = os.getenv("HOME") .. "/.hammerspoon-wifi-debug.log"

-- 디버그 로그 함수
local function debugLog(message)
    if DEBUG then
        local timestamp = os.date("%Y-%m-%d %H:%M:%S")
        local logMessage = string.format("[%s] %s\n", timestamp, message)
        
        -- 콘솔에 출력
        print(logMessage:sub(1, -2)) -- 마지막 개행 제거
        
        -- 파일에 로그 저장
        local file = io.open(LOG_FILE, "a")
        if file then
            file:write(logMessage)
            file:close()
        end
    end
end

-- 시작 로그
debugLog("=== WiFi IP 자동 전환 스크립트 시작 ===")

-- 위치 서비스 등록 (WiFi SSID 정상 작동을 위해 필요)
debugLog("위치 서비스 등록 중...")
local locationSuccess = pcall(function()
    hs.location.start()
    -- 잠시 후 중지 (권한 등록만 목적)
    hs.timer.doAfter(1, function()
        hs.location.stop()
        debugLog("위치 서비스 권한 등록 완료")
    end)
end)

if locationSuccess then
    debugLog("✅ 위치 서비스 등록 성공")
else
    debugLog("⚠️  위치 서비스 등록 실패 - 수동으로 시스템 설정에서 Hammerspoon에 위치 권한을 부여해주세요")
end

-- 사용 가능한 네트워크 서비스 확인
local function checkNetworkServices()
    debugLog("네트워크 서비스 확인 중...")
    local output, status = hs.execute("networksetup -listallnetworkservices", true)
    if status then
        debugLog("사용 가능한 네트워크 서비스:")
        for line in output:gmatch("[^\r\n]+") do
            debugLog("  - " .. line)
            if line:find("Wi%-Fi") or line:find("WiFi") or line:find("AirPort") then
                debugLog("    ^ 이 서비스가 WiFi 관련 서비스로 보입니다")
            end
        end
    else
        debugLog("네트워크 서비스 목록을 가져올 수 없습니다: " .. (output or "알 수 없는 오류"))
    end
end

-- wifi-ip-switch.sh 스크립트 존재 확인
local function checkScript()
    debugLog("WiFi IP 스위치 스크립트 확인 중...")
    local scriptPath = "/usr/local/bin/wifi-ip-switch.sh"
    local output, status = hs.execute("ls -la " .. scriptPath, true)
    if status then
        debugLog("스크립트 파일 존재 확인: " .. scriptPath)
        debugLog("파일 정보: " .. (output or "정보 없음"))
    else
        debugLog("❌ 스크립트 파일이 존재하지 않습니다: " .. scriptPath)
        debugLog("오류: " .. (output or "알 수 없는 오류"))
    end
    
    -- sudoers 권한 확인 (파일 존재 여부와 내용 확인)
    local sudoersFile = "/etc/sudoers.d/wifi-ip-switch"
    
    -- 파일 존재 확인 (ls 명령어로)
    local lsOutput, lsStatus = hs.execute("ls -la " .. sudoersFile .. " 2>/dev/null", true)
    if lsStatus then
        debugLog("✅ sudoers 권한 파일 존재 확인:")
        debugLog("  파일: " .. sudoersFile)
        debugLog("  권한: " .. (lsOutput or "정보 없음"):gsub("\n", ""))
        
        -- 내용 확인 (sudo로 읽기)
        local sudoOutput, sudoStatus = hs.execute("sudo cat " .. sudoersFile .. " 2>/dev/null", true)
        if sudoStatus and sudoOutput then
            debugLog("  내용: " .. sudoOutput:gsub("\n", " | "))
        else
            debugLog("⚠️  내용 읽기 실패 (sudo 권한 필요할 수 있음)")
        end
    else
        debugLog("❌ sudoers 권한 파일이 존재하지 않습니다: " .. sudoersFile)
        debugLog("   설치 스크립트를 다시 실행하거나 수동으로 생성하세요")
    end
end

-- 규칙(우선순위 상단 → 하단). match가 true가 되는 첫 규칙을 적용
local rules = {
  -- 1) SSID에 'iPhone' 문자열이 포함되면 모두 동일 수동 IP
  {
    name = "iPhone 핫스팟",
    match = function(ssid)
      return ssid and ssid:lower():find("iphone", 1, true) ~= nil
    end,
    profile = {
      mode="manual",
      ip="172.20.10.6", mask="255.255.255.0", router="172.20.10.1",
      dns={"1.0.0.1"}
    }
  },
  -- 2) 특정 이름의 SSID는 지정 수동 IP + DNS, 수정해서 사용
  {
    name = "Office WiFi",
    match = function(ssid) return ssid == "office" end,
    profile = {
      mode="manual",
      ip="192.168.153.106", mask="255.255.255.0", router="192.168.155.1",
      dns={"168.126.63.1","168.126.63.2"},
    }
  },
  -- 3) 그 외는 DHCP
  {
    name = "기본 DHCP",
    match = function(_) return true end,
    profile = { mode="dhcp" }
  }
}

local function toCsv(t)
  if type(t) ~= "table" or #t == 0 then return "" end
  return table.concat(t, ",")
end

local function applyProfile(p, ssid, ruleName)
  debugLog("프로필 적용 시작: " .. (ruleName or "알 수 없음"))
  debugLog("SSID: " .. (ssid or "null"))
  debugLog("모드: " .. (p.mode or "null"))
  
  local cmd = ""
  local success = false
  local output = ""
  
  if p.mode == "manual" then
    local dnsCsv = toCsv(p.dns)
    cmd = string.format(
      'sudo /usr/local/bin/wifi-ip-switch.sh manual %q %q %q %q %q',
      SERVICE, p.ip, p.mask, p.router, dnsCsv or ""
    )
    debugLog("수동 IP 설정:")
    debugLog("  IP: " .. (p.ip or "null"))
    debugLog("  Mask: " .. (p.mask or "null"))
    debugLog("  Router: " .. (p.router or "null"))
    debugLog("  DNS: " .. (dnsCsv or "null"))
  else
    cmd = string.format('sudo /usr/local/bin/wifi-ip-switch.sh dhcp %q', SERVICE)
    debugLog("DHCP 설정")
  end
  
  debugLog("실행할 명령: " .. cmd)
  
  -- 명령 실행
  output, success = hs.execute(cmd, true)
  
  if success then
    debugLog("✅ 명령 실행 성공")
    if output and output ~= "" then
      debugLog("명령 출력: " .. output)
    end
    
    -- 성공 알림
    local notificationText = ""
    if p.mode == "manual" then
      notificationText = (ssid or "(unknown)").." → 수동 "..p.ip
    else
      notificationText = (ssid or "(unknown)").." → DHCP"
    end
    
    hs.notify.new({
      title="Wi-Fi IP 전환 성공",
      informativeText=notificationText,
      soundName="Glass"
    }):send()
    
  else
    debugLog("❌ 명령 실행 실패")
    debugLog("오류 출력: " .. (output or "알 수 없는 오류"))
    
    -- 실패 알림
    hs.notify.new({
      title="Wi-Fi IP 전환 실패",
      informativeText="SSID: " .. (ssid or "unknown") .. "\n오류: " .. (output or "알 수 없음"),
      soundName="Basso"
    }):send()
  end
  
  -- 설정 후 현재 네트워크 상태 확인
  debugLog("설정 후 네트워크 상태 확인...")
  local statusOutput, statusSuccess = hs.execute("networksetup -getinfo " .. SERVICE, true)
  if statusSuccess then
    debugLog("현재 네트워크 설정:")
    debugLog(statusOutput or "정보 없음")
  else
    debugLog("네트워크 상태 확인 실패: " .. (statusOutput or "알 수 없음"))
  end
end

local last = nil
local function onWifiChange()
  local ssid = hs.wifi.currentNetwork()
  debugLog("WiFi 변경 감지됨")
  debugLog("현재 SSID: " .. (ssid or "null"))
  debugLog("이전 SSID: " .. (last or "null"))
  
  if ssid and ssid ~= last then
    debugLog("새로운 WiFi 네트워크 연결: " .. ssid)
    
    -- 규칙 순서대로 검사해 첫 번째 매칭 프로필 적용
    local matched = false
    for i, r in ipairs(rules) do
      debugLog("규칙 " .. i .. " 확인: " .. (r.name or "이름없음"))
      if r.match(ssid) then
        debugLog("✅ 규칙 매칭됨: " .. (r.name or "이름없음"))
        applyProfile(r.profile, ssid, r.name)
        matched = true
        break
      else
        debugLog("❌ 규칙 매칭 안됨: " .. (r.name or "이름없음"))
      end
    end
    
    if not matched then
      debugLog("⚠️  어떤 규칙도 매칭되지 않았습니다")
    end
    
    last = ssid
  elseif ssid == last then
    debugLog("동일한 SSID - 처리 건너뜀")
  elseif not ssid then
    debugLog("WiFi 연결 해제됨")
    last = nil
  end
  
  debugLog("WiFi 변경 처리 완료")
  debugLog("---")
end

-- 초기화
debugLog("초기화 시작...")
checkNetworkServices()
checkScript()

-- WiFi 감시자 시작
debugLog("WiFi 감시자 시작...")
wifiWatcher = hs.wifi.watcher.new(onWifiChange):start()

-- 로드 직후에도 한 번 적용
debugLog("초기 WiFi 상태 확인...")
onWifiChange()

debugLog("=== 초기화 완료 ===")

-- 디버그 정보 출력 함수 (수동 호출용)
function showDebugInfo()
    debugLog("=== 수동 디버그 정보 요청 ===")
    checkNetworkServices()
    checkScript()
    onWifiChange()
    
    -- 로그 파일 위치 알림
    hs.notify.new({
        title="디버그 정보",
        informativeText="로그 파일: " .. LOG_FILE .. "\nHammerspoon Console에서도 확인 가능",
        soundName="Glass"
    }):send()
    
    print("디버그 로그 파일: " .. LOG_FILE)
    print("Hammerspoon Console에서 실시간 로그를 확인하세요.")
end

-- 단축키로 디버그 정보 확인 (Cmd+Shift+D)
hs.hotkey.bind({"cmd", "shift"}, "D", showDebugInfo)
onWifiChange() -- 로드 직후에도 한 번 적용