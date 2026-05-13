function Hero() {
  return (
    <section className="viv-hero">
      <div className="viv-hero__inner">
        <h1 className="viv-hero__title">
          Sourcing et placement<br/>
          <em>des meilleurs talents</em><br/>
          pour accélérer la performance<br/>
          de <em>vos projets.</em>
        </h1>
        <p className="viv-hero__lead">
          Spécialiste de la mise à disposition de talents, VIV accompagne les entreprises
          dans l'intégration rapide de profils experts au sein de leurs équipes. Un modèle
          agile, conforme et durable, pour des collaborations efficaces dès le premier jour.
        </p>
        <div className="viv-hero__ctas">
          <a className="viv-btn viv-btn--primary" href="#talents">Découvrez nos talents →</a>
          <a className="viv-btn viv-btn--ghost-light" href="#engagements">Nos engagements</a>
        </div>
      </div>
      <div className="viv-hero__mark">
        <img src="../../assets/logos/viv-vertical-green.png" alt="" aria-hidden />
      </div>
    </section>
  );
}
window.Hero = Hero;
