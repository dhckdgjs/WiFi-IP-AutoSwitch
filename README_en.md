# WiFi Static IP Auto Switcher for macOS

A macOS utility (powered by Hammerspoon) that automatically configures IP/DNS/Gateway settings based on WiFi SSID.  
(Useful when iPhone tethering/hotspot fails to assign a valid IP address.)

* **Why Hammerspoon?**  
  Other methods (IP/ARP checks, Location changes, etc.) suffer from macOS security restrictions, slow IP switching, or unreliable SSID parsing.  
  Hammerspoon provides a faster, smoother, and more reliable solution.

---

## 🌟 Features

- **Automatic IP Assignment**: Switches IP settings automatically when WiFi SSID changes  
- **Flexible Rule System**: Configure static IP or DHCP per SSID  
- **Custom DNS**: Assign different DNS servers per SSID  
- **Instant Notifications**: Get macOS notifications when settings are updated  

---

## 📋 Requirements

- **macOS**: 10.12 Sierra or later  
- **Hammerspoon**: 0.9.76 or later  
- **Admin Privileges**: Required for network configuration changes  
- **Location Services Permission**: Required for accurate SSID detection (script includes auto-grant logic)  

---

## 🚀 Installation

### Step 1: Install Hammerspoon

If you don’t have Hammerspoon installed:

```bash
# Using Homebrew
brew install --cask hammerspoon

# Or download manually
# https://www.hammerspoon.org/
```

### Step 2: Run Setup Script 🌟

```bash
# Default installation
bash setup.sh

# Explicit installation
bash setup.sh install
```

> 💡 **Note**: Without the required permissions, IP switching will not work.  
> The script automatically prompts for Location Services permission—if denied, the script cannot function.  
> (It uses `hs.location.start()` to request permission.)

<br>
<p align="left">
<img width="295" height="372" alt="Screenshot 1" src="https://github.com/user-attachments/assets/118d3fc2-959b-472e-8502-73380996d970" />
<img width="295" height="372" alt="Screenshot 2" src="https://github.com/user-attachments/assets/4cc94a6b-f4bf-4615-bd12-8b409a60d86b" />
</p>
<br>

The installer automatically handles:  
- ✅ Checking required files & permissions (`settings/` folder)  
- ✅ Installing WiFi script to `/usr/local/bin/`  
- ✅ Adding sudoers entry (no password needed for network changes)  
- ✅ Deploying Hammerspoon config (`settings/init.lua`)  
- ✅ Backing up existing configs  

---

## ⚙️ Configuration

After installation, edit `~/.hammerspoon/init.lua` to define SSID rules.

### Example Rules

```lua
local rules = {
  -- 1) iPhone Hotspot
  {
    match = function(ssid)
      return ssid and ssid:lower():find("iphone", 1, true) ~= nil
    end,
    profile = {
      mode="manual",
      ip="172.20.10.5", 
      mask="255.255.255.0", 
      router="172.20.10.1",
      dns={"1.1.1.1", "8.8.8.8"}
    }
  },
  
  -- 2) Office WiFi
  {
    match = function(ssid) return ssid == "office" end,
    profile = {
      mode="manual",
      ip="192.168.153.105", 
      mask="255.255.255.0", 
      router="192.168.155.1",
      dns={"168.126.63.1", "168.126.63.2"}
    }
  },
  
  -- 3) Default → DHCP
  {
    match = function(_) return true end,
    profile = { mode="dhcp" }
  }
}
```

### Adding New Rules

1. Open `~/.hammerspoon/init.lua`  
2. Add a new rule under `rules`  

```lua
-- Example: Company WiFi
{
  match = function(ssid) return ssid == "Company-WiFi" end,
  profile = {
    mode="manual",
    ip="10.0.1.100",
    mask="255.255.255.0",
    router="10.0.1.1",
    dns={"10.0.1.1", "8.8.8.8"}
  }
},
```

3. Reload Hammerspoon: `⌘ + Space` → "Hammerspoon" → "Reload Config"

---

## 🔧 Usage

### Basic Usage
1. **Auto-run**: Runs automatically while Hammerspoon is active  
2. **Test**: Switch WiFi networks to see auto-config in action  
3. **Status**: macOS notifications show when settings are applied  
4. **Logs**: View logs at `/var/log/ssid-ip-switcher.log`  

### Setup Script Commands
```bash
# Show help
bash setup.sh help

# Install
bash setup.sh
bash setup.sh install

# Uninstall
bash setup.sh uninstall
```

---

## 🛠️ Troubleshooting

### Hammerspoon Not Running
```bash
ps aux | grep Hammerspoon
open -a Hammerspoon
```

### Permission Issues
```bash
sudo cat /etc/sudoers.d/wifi-ip-switch
ls -la /usr/local/bin/wifi-ip-switch.sh
```

### Rules Not Applying
1. Reload Hammerspoon config  
2. Check syntax in `~/.hammerspoon/init.lua`  
3. Check Hammerspoon Console for errors  

### Network Service Name Mismatch
```bash
# List network services
networksetup -listallnetworkservices
```

Update in `init.lua`:
```lua
local SERVICE = "Wi-Fi"  -- or "WiFi", "AirPort"
```

---

## 📁 File Structure

```
WiFi-IP-Switch/
├── setup.sh                # 🌟 Main installer script
├── settings/               # Config files
│   ├── install.sh          # Installer
│   ├── uninstall.sh        # Uninstaller
│   ├── wifi-ip-switch.sh   # Network switch script
│   └── init.lua            # Hammerspoon config
└── docs/                   # Documentation
    ├── README.md           # Full guide
    └── INSTALL_GUIDE.md    # Quick install guide
```

---

## 🔄 Uninstallation

```bash
# Safe uninstall
bash setup.sh uninstall
```

Or manually:
```bash
sudo rm -f /usr/local/bin/wifi-ip-switch.sh
sudo rm -f /etc/sudoers.d/wifi-ip-switch
mv ~/.hammerspoon/init.lua ~/.hammerspoon/init.lua.backup
```

---

## 📝 Logs

```bash
tail -f /var/log/ssid-ip-switcher.log
```

Check Hammerspoon Console:  
**Hammerspoon → Help → Console**

---

## ⚠️ Notes

- **Security**: Edits `sudoers`—use only in trusted environments  
- **Backup**: Backup network settings before first install  
- **Testing**: Test thoroughly before using in production environments  
- **Editing Rules**: Modify `~/.hammerspoon/init.lua` after installation  
- **Packaging**: Use `create-pkg.sh` for easy installer creation  

---

## 🤝 Contributing

Please open an issue for bug reports or feature requests.  

---

## 📄 License

MIT License  

---

**⭐ If you find this useful, please give it a star!**
