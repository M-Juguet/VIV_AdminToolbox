function Footer() {
  return (
    <footer className="viv-footer" id="contact">
      <div className="viv-footer__top">
        <div className="viv-footer__brand">
          <img src="../../assets/logos/viv-horizontal-white.png" alt="VIV" />
          <p>Sourcing et placement des meilleurs talents pour accélérer la performance de vos projets.</p>
        </div>
        <div>
          <h5>Menu</h5>
          <ul><li><a href="#">Nos talents</a></li><li><a href="#">Nos secteurs</a></li><li><a href="#">Nos engagements</a></li><li><a href="#">Écosystème</a></li></ul>
        </div>
        <div>
          <h5>À propos</h5>
          <ul><li><a href="#">Mentions légales</a></li><li><a href="#">Conditions d'utilisation</a></li><li><a href="#">Données personnelles</a></li><li><a href="#">Cookies</a></li></ul>
        </div>
        <div>
          <h5>Contact</h5>
          <ul>
            <li>14, rue de Mantes</li>
            <li>Colombes 92700</li>
            <li>+33 (0)1 42 42 46 93</li>
            <li><a href="mailto:contact@viv-prod.com">contact@viv-prod.com</a></li>
          </ul>
        </div>
      </div>
      <div className="viv-footer__bottom">
        <span>© 2025 VIV. Tous droits réservés.</span>
        <div className="viv-footer__social">
          <a href="#">LinkedIn</a>
          <a href="#">Instagram</a>
        </div>
      </div>
    </footer>
  );
}
window.Footer = Footer;
