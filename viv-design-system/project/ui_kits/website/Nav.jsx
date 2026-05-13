function Nav() {
  const [scrolled, setScrolled] = React.useState(false);
  React.useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 20);
    window.addEventListener('scroll', onScroll);
    return () => window.removeEventListener('scroll', onScroll);
  }, []);
  return (
    <nav className={`viv-nav ${scrolled ? 'is-scrolled' : ''}`}>
      <a href="#" className="viv-nav__logo">
        <img src="../../assets/logos/viv-horizontal-white.png" alt="VIV" />
      </a>
      <ul className="viv-nav__links">
        <li><a href="#talents">Nos talents</a></li>
        <li><a href="#secteurs">Nos secteurs</a></li>
        <li><a href="#engagements">Nos engagements</a></li>
        <li><a href="#ecosysteme">Notre écosystème VIV</a></li>
      </ul>
      <a className="viv-btn viv-btn--primary" href="#contact">Contact</a>
    </nav>
  );
}
window.Nav = Nav;
