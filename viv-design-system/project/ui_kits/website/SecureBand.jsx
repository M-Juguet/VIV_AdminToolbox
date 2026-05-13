function SecureBand() {
  return (
    <section className="viv-secure" id="ecosysteme">
      <div className="viv-secure__inner">
        <span className="viv-eyebrow viv-eyebrow--on-dark">Secure</span>
        <h2 className="viv-h2 viv-h2--on-dark">
          L'offre complémentaire qui<br/>
          <em>centralise vos talents.</em>
        </h2>
        <p className="viv-secure__lead">
          Nous reprenons la gestion de vos talents déjà en mission ou intégrés dans vos équipes,
          pour leur offrir un cadre clair et conforme.
        </p>
        <div className="viv-secure__pillars">
          <div><h4>Vos équipes, vos projets</h4><p>Vous conservez vos talents simplement.</p></div>
          <div><h4>Des talents protégés</h4><p>Nous les encadrons, sécurisons et accompagnons.</p></div>
          <div><h4>Conformité assurée</h4><p>Juridique et conformité, unifiés par VIV.</p></div>
        </div>
        <a className="viv-btn viv-btn--primary" href="#">En savoir plus →</a>
      </div>
    </section>
  );
}
window.SecureBand = SecureBand;
