# React Component Patterns

## Composition

### Children Pattern
```jsx
function Card({ children }) {
  return <div className="card">{children}</div>;
}

<Card>
  <h2>Title</h2>
  <p>Content</p>
</Card>
```

### Compound Components
```jsx
function Tabs({ children, defaultTab }) {
  const [active, setActive] = useState(defaultTab);
  return (
    <TabsContext.Provider value={{ active, setActive }}>
      {children}
    </TabsContext.Provider>
  );
}

Tabs.List = function TabList({ children }) {
  return <div className="tab-list">{children}</div>;
};

Tabs.Tab = function Tab({ value, children }) {
  const { active, setActive } = useContext(TabsContext);
  return (
    <button
      className={active === value ? 'active' : ''}
      onClick={() => setActive(value)}
    >
      {children}
    </button>
  );
};

Tabs.Panel = function TabPanel({ value, children }) {
  const { active } = useContext(TabsContext);
  return active === value ? <div>{children}</div> : null;
};

// Usage
<Tabs defaultTab="one">
  <Tabs.List>
    <Tabs.Tab value="one">Tab 1</Tabs.Tab>
    <Tabs.Tab value="two">Tab 2</Tabs.Tab>
  </Tabs.List>
  <Tabs.Panel value="one">Content 1</Tabs.Panel>
  <Tabs.Panel value="two">Content 2</Tabs.Panel>
</Tabs>
```

### Slots Pattern
```jsx
function Layout({ header, sidebar, children }) {
  return (
    <div className="layout">
      <header>{header}</header>
      <aside>{sidebar}</aside>
      <main>{children}</main>
    </div>
  );
}

<Layout
  header={<NavBar />}
  sidebar={<Menu />}
>
  <Article />
</Layout>
```

## Error Boundaries

Class components only (no hook equivalent yet):

```jsx
class ErrorBoundary extends React.Component {
  state = { hasError: false, error: null };

  static getDerivedStateFromError(error) {
    return { hasError: true, error };
  }

  componentDidCatch(error, info) {
    console.error('Error:', error, info.componentStack);
  }

  render() {
    if (this.state.hasError) {
      return this.props.fallback || <p>Something went wrong</p>;
    }
    return this.props.children;
  }
}

// Usage
<ErrorBoundary fallback={<ErrorPage />}>
  <App />
</ErrorBoundary>
```

### react-error-boundary Library
```jsx
import { ErrorBoundary, useErrorBoundary } from 'react-error-boundary';

function Fallback({ error, resetErrorBoundary }) {
  return (
    <div>
      <p>Error: {error.message}</p>
      <button onClick={resetErrorBoundary}>Retry</button>
    </div>
  );
}

<ErrorBoundary FallbackComponent={Fallback} onReset={() => refetch()}>
  <DataComponent />
</ErrorBoundary>

// Programmatic error throwing
function ChildComponent() {
  const { showBoundary } = useErrorBoundary();

  async function handleClick() {
    try {
      await riskyOperation();
    } catch (error) {
      showBoundary(error);
    }
  }
}
```

## Portals

Render children outside parent DOM hierarchy:

```jsx
import { createPortal } from 'react-dom';

function Modal({ children, isOpen }) {
  if (!isOpen) return null;

  return createPortal(
    <div className="modal-overlay">
      <div className="modal-content">
        {children}
      </div>
    </div>,
    document.body
  );
}

// Events still bubble through React tree (not DOM tree)
<div onClick={() => console.log('clicked')}>
  <Modal isOpen={true}>
    <button>Click me</button> {/* onClick bubbles to parent div */}
  </Modal>
</div>
```

### Tooltip Example
```jsx
function Tooltip({ children, content, targetRef }) {
  const [position, setPosition] = useState({ top: 0, left: 0 });

  useLayoutEffect(() => {
    if (targetRef.current) {
      const rect = targetRef.current.getBoundingClientRect();
      setPosition({ top: rect.bottom + 8, left: rect.left });
    }
  }, [targetRef]);

  return createPortal(
    <div className="tooltip" style={position}>
      {content}
    </div>,
    document.body
  );
}
```

## Forwarding Refs

```jsx
const Input = forwardRef(function Input(props, ref) {
  return <input ref={ref} {...props} />;
});

// Parent can access input DOM node
function Form() {
  const inputRef = useRef();
  return (
    <>
      <Input ref={inputRef} />
      <button onClick={() => inputRef.current.focus()}>Focus</button>
    </>
  );
}
```

### With useImperativeHandle
```jsx
const VideoPlayer = forwardRef(function VideoPlayer({ src }, ref) {
  const videoRef = useRef();

  useImperativeHandle(ref, () => ({
    play: () => videoRef.current.play(),
    pause: () => videoRef.current.pause(),
    seek: (time) => videoRef.current.currentTime = time
  }), []);

  return <video ref={videoRef} src={src} />;
});

// Parent uses custom API
function App() {
  const playerRef = useRef();
  return (
    <>
      <VideoPlayer ref={playerRef} src="movie.mp4" />
      <button onClick={() => playerRef.current.play()}>Play</button>
      <button onClick={() => playerRef.current.seek(30)}>Skip to 0:30</button>
    </>
  );
}
```

## Higher-Order Components

Still useful for cross-cutting concerns (prefer hooks when possible):

```jsx
function withAuth(Component) {
  return function AuthenticatedComponent(props) {
    const { user, isLoading } = useAuth();

    if (isLoading) return <Loading />;
    if (!user) return <Navigate to="/login" />;

    return <Component {...props} user={user} />;
  };
}

const ProtectedDashboard = withAuth(Dashboard);
```

### When to Use HOCs vs Hooks

**Prefer Hooks:**
- Sharing stateful logic
- Most cases

**Prefer HOCs:**
- Wrapping with providers/contexts
- Adding props conditionally
- Route-level concerns (auth guards)

## Render Props (Legacy Pattern)

Hooks usually better, but still useful for render customization:

```jsx
function MouseTracker({ render }) {
  const [position, setPosition] = useState({ x: 0, y: 0 });

  useEffect(() => {
    const handleMove = (e) => setPosition({ x: e.clientX, y: e.clientY });
    window.addEventListener('mousemove', handleMove);
    return () => window.removeEventListener('mousemove', handleMove);
  }, []);

  return render(position);
}

// Usage
<MouseTracker render={({ x, y }) => (
  <div>Mouse: {x}, {y}</div>
)} />

// Better: Custom hook
function useMousePosition() {
  const [position, setPosition] = useState({ x: 0, y: 0 });
  // ... same logic
  return position;
}
```

## Context Pattern

```jsx
const ThemeContext = createContext(null);

function ThemeProvider({ children }) {
  const [theme, setTheme] = useState('light');
  const value = useMemo(() => ({ theme, setTheme }), [theme]);

  return (
    <ThemeContext.Provider value={value}>
      {children}
    </ThemeContext.Provider>
  );
}

function useTheme() {
  const context = useContext(ThemeContext);
  if (!context) throw new Error('useTheme must be within ThemeProvider');
  return context;
}

// Usage
<ThemeProvider>
  <App />
</ThemeProvider>

function Button() {
  const { theme, setTheme } = useTheme();
  return <button className={theme}>Toggle</button>;
}
```
