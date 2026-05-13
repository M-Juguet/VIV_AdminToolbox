function Certifications() {
  return (
    <section className="viv-certs">
      <span className="viv-eyebrow">Notre engagement par des certifications</span>
      <div className="viv-certs__row">
        <div className="viv-cert">
          <div className="viv-cert__badge viv-cert__badge--gold">EcoVadis<br/><small>2024 · Or</small></div>
          <p>La médaille d'Or EcoVadis, attestant de notre engagement en matière de responsabilité sociale, éthique et environnementale.</p>
        </div>
        <div className="viv-cert">
          <div className="viv-cert__badge">ISO<br/><strong>9001</strong></div>
          <p>Une reconnaissance de la rigueur de nos processus et de notre engagement à offrir un accompagnement conforme aux standards de qualité.</p>
        </div>
        <div className="viv-cert">
          <div className="viv-cert__badge">Qualiopi</div>
          <p>Notre centre de formation est agréé Qualiopi et accompagne la montée en compétence de nos talents et partenaires sur les usages de l'IA.</p>
        </div>
      </div>
    </section>
  );
}
window.Certifications = Certifications;
