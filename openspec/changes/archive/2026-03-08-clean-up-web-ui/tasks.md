## 1. CSS Layout and Styling

- [x] 1.1 Add vertical centering to body (align-items: center + min-height: 100vh)
- [x] 1.2 Add .choice-btn:focus style with accent color border/glow (#e94560)
- [x] 1.3 Add fade-in CSS animation (@keyframes fadeIn, 150ms ease-in)

## 2. Keyboard Navigation

- [x] 2.1 Add keydown listener for arrow key navigation between choice buttons (wrap-around)
- [x] 2.2 Add Enter/Space activation for focused choice button
- [x] 2.3 Add number key (1-9) shortcuts that activate corresponding choice (skip when text input focused)

## 3. Focus Management

- [x] 3.1 Auto-focus first choice button after renderStep creates buttons
- [x] 3.2 Apply fade-in class to game-output and game-controls after each render

## 4. Verify

- [x] 4.1 Build succeeds and open in browser
- [x] 4.2 Verify vertical centering with short and long content
- [x] 4.3 Verify keyboard navigation (arrows, Enter/Space, number keys)
- [x] 4.4 Verify focus indicator visibility on buttons
