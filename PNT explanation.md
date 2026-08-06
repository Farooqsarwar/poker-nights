Poker Night MVP — Human Product Guide 

#### **POKER NIGHT** 

# **Detailed Product Guide** 

**_A clear, non-technical explanation of what Poker Night does and how people use it_** 

**MVP Scope v2.0** 

**_Web-first MVP • One administrator • Tournament + minimal cash mode • No Spotify_** 

1 

Poker Night MVP — Human Product Guide 

## **Contents** 

**1. What Poker Night is** 

**2. Who uses it** 

**3. What is included now** 

**4. How a tournament works** 

**5. How the automatic structure works** 

**6. Invitations and guests** 

**7. Running the game** 

**8. TV and voice** 

**9. Chat, polls and notifications** 

**10. History and statistics** 

**11. Cash games** 

**12. What is intentionally postponed** 

**13. Example poker night** 

2 

Poker Night MVP — Human Product Guide 

## **1. What Poker Night Is** 

Poker Night is a website that helps one person organise and run a private Texas Hold’em game. It is designed for home poker nights where the host currently has to manage messages, attendance, chips, blinds, a timer, rebuys, seating and prizes manually. 

The host gives Poker Night a small amount of information. The app then prepares a tournament that fits the number of people, the available time and the physical chips that actually exist in the host’s poker set. 

##### **The simple idea** 

The host decides what kind of poker night they want. Poker Night handles the organisation and suggests the structure. The host always makes the final decision. 

## **2. Who Uses It** 

### **Administrator** 

There is one administrator for each game. This is usually the host. The administrator creates the game, chooses the settings, confirms guests, starts the timer and records everything that happens during the tournament. 

### **Registered player** 

A registered player can join the private group, answer invitations, use chat and polls, receive notifications, check in and view the live tournament from their phone. 

### **Guest** 

A guest does not need an account. They open the tournament website with a code or QR link, select who invited them, choose the correct guest slot and enter their name. After the host confirms them, they can see their table, seat, timer and other basic game information. Guests cannot use chat or polls unless they create an account. 

## **3. What Is Included Now** 

- One responsive website that works on phones, tablets, laptops and TV browsers. 

- Private groups, invitations, guest places and check-in. 

- An automatic tournament generator based on players, duration and chips. 

- A live timer with blinds, ante, players remaining and average stack. 

- Rebuys, add-ons, knockouts, seating and final-table redraw. 

- A private prize calculator for the host. 

- A public TV page opened with a code or link. 

- Simple English voice announcements. 

- Group chat, polls and browser/in-app notifications. 

- Group game history and a few simple player statistics. 

- A basic cash-game section. 

### **What is not included in the first version** 

- Spotify 

- Native iPhone and Android apps 

- Built-in Chromecast or AirPlay buttons 

- More than one administrator per game 

- Advanced player graphs and financial statistics 

- Complex social features or achievements 

- Payment processing 

3 



<!-- Start of picture text -->
Create game Generate and confirm Invite, RSVP, Run timer and End rebuy period Continue with optional Final-table redraw Record result<br>Choose preset or inputs stack, blinds, chips, payouts check in and seat record game actions settle rebuys/add-ons confirmed changes when 9 remain and close game<br><!-- End of picture text -->

Poker Night MVP — Human Product Guide 

## **5. How the Automatic Structure Works** 

Poker Night does not force every game to start with the same stack or blinds. A stack of 5,000 can be deep at 25/50, but far too deep at 5/10. The app therefore solves the stack and blinds together. 

It first checks which blind values are easy to pay with the available chips. A blind such as 20/50 is acceptable when it is simpler than 25/50. The small blind does not always have to be exactly half the big blind. The important thing is that players can follow the numbers easily and post the blinds without constant change. 

Every level lasts exactly 10, 15 or 20 minutes. Normally, the complete tournament uses one level duration. The app estimates how many levels fit inside the chosen duration, how quickly blinds need to grow and roughly when the tournament should end. 

### **Changes during the game** 

The host can still change the future structure during play. Poker Night can estimate that the tournament is finishing too early or too late and suggest speeding up or slowing down. A speed-up can shorten future levels or add an ante. A slow-down can make future levels longer or add an extra intermediate blind level. The active level never changes, and the host must approve every adjustment. 

## **6. Invitations and Guests** 

Every group has a private code. Every tournament also has a code and shareable link. The tournament page offers a normal player route, a guest route and a TV display route. 

### **Guest example** 

**1.** Maria answers Going +2. 

**2.** Her two friends open the tournament link. 

**3.** Each friend chooses Maria as the inviter. 

**4.** One chooses Maria’s Guest 1 and the other chooses Guest 2. 

**5.** They enter their names and request check-in. 

**6.** The host confirms both guests. 

**7.** Each guest receives a table and seat on the website. 

Players may change their attendance response until one hour before the game. The host can still manage attendance before late registration closes. After the rebuy period ends, nobody new can enter. 

## **7. Running the Game** 

### **What the host sees** 

- Large timer and level controls 

- Current and next blinds 

- Player list and seating 

- Buttons for elimination, rebuy and add-on 

- Estimated finishing time 

- Speed Up, Slow Down and Edit Future Levels 

- Prize calculation and chip-exchange instructions 

- Undo/correction controls 

### **What players see** 

- Timer, blinds and ante 

- Next level 

- Players remaining 

5 

Poker Night MVP — Human Product Guide 

- Average stack 

- Their own seat 

- Announcements 

- The total Prize Pool while the game is active 

Players do not see who rebought, who purchased an add-on, the organizer percentage or individual payout amounts. 

### **Recovery if something goes wrong** 

The host’s browser saves the active tournament on the device. If the page refreshes or the internet disappears temporarily, the host can restore the timer and game state. Other players and TVs need an internet connection and show the last known information until they reconnect. 

## **8. TV and Voice** 

TV Mode is simply a clean website page. The host opens it on a TV browser with the code or mirrors it from another device. There is no special Spotify or casting integration in the first version. 

- Large timer 

- Current blinds and ante 

- Next level 

- Players remaining 

- Average stack 

- Prize Pool during the game 

- Announcements 

- Final-table seating and final podium 

The host manually chooses one device to speak. It uses a normal English browser voice for announcements such as a new level, five minutes remaining, one minute remaining, rebuys closed, final table, dealer position and winner. Eliminated-player names are optional and off by default. 

## **9. Chat, Polls and Notifications** 

### **Chat** 

Registered members have a simple group chat and can also have a chat connected to a specific tournament. Guests cannot use chat. The host can remove inappropriate messages. 

### **Polls** 

The host can ask members to vote on the date, start time, buy-in, knockout format, duration, location or another question. Poll results can help Poker Night suggest a saved tournament preset. 

### **Notifications** 

Players receive an in-app notification and, when their browser allows it, a browser push notification. Examples include a new tournament, an RSVP deadline, a new poll, a confirmed seat and a game starting soon. 

## **10. History and Statistics** 

The group keeps a simple list of completed games. Members can see the date, game name, attendance and final positions. They do not see prize amounts. 

The first version keeps only five basic player statistics: games played, wins, podium finishes, average finish and knockouts. It does not include personal profit, ROI, detailed rebuy history, graphs or a separate personal game-history page. 

6 



<!-- Start of picture text -->
Create session Add and Start session Record buy-ins Record Reconcile Save session<br>and fixed blinds seat players timer and top-ups cash-outs totals summary<br><!-- End of picture text -->



