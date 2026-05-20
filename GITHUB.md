# Put Steam Idle Mac on GitHub (simple guide)

Your username: **chic0beans**  
Download page: **https://github.com/chic0beans/SteamIdleMac/releases**

---

## You do NOT need Homebrew

If Terminal says `command not found: brew`, use these commands instead.

### Step 1 — Install GitHub login tool (one time)

```bash
cd ~/Documents/SteamIdleMac
bash scripts/install-tools.sh
```

Close Terminal and open a **new** Terminal window, then:

```bash
gh auth login
```

Pick: **GitHub.com** → **HTTPS** → **Login with a web browser**  
Sign in as **chic0beans** and click Authorize.

### Step 2 — Put project on GitHub (one time)

```bash
cd ~/Documents/SteamIdleMac
bash scripts/setup-github.sh
```

### Step 3 — Upload app for people to download (any time)

```bash
cd ~/Documents/SteamIdleMac
bash scripts/publish.sh
```

Share this link: **https://github.com/chic0beans/SteamIdleMac/releases**

---

## What friends do

1. Open the link above
2. Download **SteamIdleMac.dmg**
3. Drag the app to Applications
4. First open: right-click app → **Open**

---

## Optional: Homebrew later

If you want Homebrew for other stuff: https://brew.sh  
You do **not** need it for this project.
