/***
* Name: EPIDEMIE
* Author: celicourt
* Description: 
* Tags: Tag1, Tag2, TagN
***/

model TEpidemie


global{ 
	
	
    int nb_PerCorrectes       <- 1500  parameter: "Nombre PerCorrectes" min:10 max:100000;
    int nb_contamines_init    <- 120   parameter: "Nombre de gens contamines" min:5  max: 500;  // 10 people have been already contamines.
    int nb_Medecin            <- 100   parameter: "Nombre de Medecins" min:5 max:50; // Dans cette ville, on compte 20 medecins minimum pour 500 habitants
    int nb_dead               <- 0     parameter: "Nombre de morts";
    int nb_treated_init       <-1;
    float nb_health_          <- 1.0  parameter:'Sante Moyenne de la Communaute';
    float survivalProbability <- 1.0  parameter: 'Probabilite de survie';
    
    
    file shape_batiment       <- file   ("../includes/buil.shp");  // to change into newshape/buildings.sh
    file shape_route        <-  file    ("../includes/roads.shp");
    file shape_hopital        <-  file  ("../includes/hopital.shp"); 
    
    float step                <- 10 #mn;
    geometry shape            <-  envelope (shape_route);  // l'axe (X,Y) qui constient la forme de notre enviro
     
     
    int nb_PerCorrectes_pas_contamines           <- nb_contamines_init                   update: PerCorrectes count (each.is_contamines);
    int nb_PerCorrectes_en_sont_pas_contamines   <- nb_PerCorrectes - nb_contamines_init update: nb_PerCorrectes - nb_PerCorrectes_pas_contamines;
    int nb_treated                               <- nb_treated_init                      update: PerCorrectes count (each.is_hilled);
    
    
    float Ratio_Contamines  update:    nb_PerCorrectes_pas_contamines/nb_PerCorrectes;   // Ratio du nombre de personnes contaminées
    float Ratio_Treated     update:    nb_treated/nb_PerCorrectes_pas_contamines;       // Ratio du nombres de personnes traitées
    int   nb_contamines     update:    (nb_PerCorrectes_pas_contamines);
   
     graph road_system;
     map<Roads,float> road_weights;

    init{
    	
    	
    	create Batiment             from: shape_batiment;
        create Roads                from:shape_route;
        create HopitalMirebalais    from: shape_hopital;
               road_system          <- as_edge_graph(Roads);
               road_weights         <- Roads as_map (each::each.shape.perimeter);
               road_system          <- as_edge_graph(Roads);
        
          
        create PerCorrectes number:nb_PerCorrectes{
               my_home            <- one_of(Batiment);
               location           <- any_location_in(my_home);
               }     
        ask nb_contamines_init among PerCorrectes {
            is_contamines <- true;
            
             }

         
      create    PerAtteintes          number:nb_PerCorrectes_pas_contamines{
                is_hilled             <- false;
         	    Hp_center             <- one_of(Batiment);
                location              <- any_location_in(Hp_center);
          
             }
                
       
        
         create Medecins number:nb_Medecin{
        	    Hp_center       <- one_of (Batiment);
         	    location        <- any_location_in(Hp_center);
                my_home         <- one_of(Batiment);
                location        <- any_location_in(my_home);
            }
          }
          
   
   reflex update_road_speed  {
         road_weights        <- Roads as_map (each::each.shape.perimeter / each.speed_coeff);
        road_system          <- road_system with_weights road_weights;
        }

   reflex end_simulation when: Ratio_Contamines = 4.0
        {
       do pause;
        }
}

species name:    PerCorrectes skills:[moving]{     
        Batiment my_home;  
        bool     is_contamines <- false;   
        bool     is_hilled <- false;
	    bool     in_my_home <- true;
	    float    leaving_prob <- 0.05;
	    float    Hp_center;   
	    float    diseases_probability;  
	    float    height <- 0.5+ rnd(0.5);
	    float    speed <- 5.0 + rnd(10);
	    int      working_hour;  
	    int      leasure_time;
	    point    target;
	    rgb      color<- #blue;
    
   // reflexe de rester a la maison
   
   reflex stay when:     target = nil {
   if flip              (in_my_home ? 0.01 : 0.1) {
   Batiment bd_target   <- in_my_home ? one_of(Batiment) : my_home;
            target      <- any_location_in (bd_target);
            in_my_home  <- not in_my_home;
         }
       } 


       
    reflex move when    : target != nil{
    do    goto    target:target on: road_system;
    if        (location = target) {
    	write"heure de pointe";
    	write("rentree de bureau");
          target <- nil;
          
        } 
    }              
      // reflexe de contamination                     
   
    reflex contamines when: is_contamines{
    ask PerCorrectes at_distance 1.23 #m {
    if         flip (0.92) {
    	if diseases_probability < 1.0 {
    		write "Personne succeptible d'etre contamine a l'epidemie";
    	         }
    	is_contamines <- true;
    	write "Nouvelle personne contaminee";
    	loop times: 6 {
        heading       <-  (int(Hp_center));
       do move;
         }
       do    goto target:target on: Hp_center;  // Once contamines, infected people go to the Health Center
       if   (location   = target) {
    	target          <- nil;
          
            }
           }
          }
        }
               
           aspect PerCorrectes{
    	
        draw sphere(5)  color:is_contamines ? rgb(#red): rgb(#blue);
        
      }
   }



species name: PerAtteintes skills: [moving]{
    	
    float contamination_level; // Niveau de cas de contamination
	Batiment Hp_center           <- Batiment(#pink);
	bool inside_health_center   <- false;
    point target;
	float height                 <- 0.5 + rnd(0.5);
	bool is_hilled               <- false;
	bool is_contamines           <-false;
	
	
	
	// Réflexe pour rester à la maison quand aucune activité n'est programmée
	reflex stay when:     target = nil {
    if flip(inside_health_center ? 0.05 : 0.8) {
    Batiment bd_target           <- inside_health_center ? one_of(Batiment) : Hp_center;
            target               <- any_location_in (bd_target);
            inside_health_center <- not inside_health_center;
         }
       } 
   
   
   
//   Réflexe pour sortir quand est le temps de travail, l'école ou les loisirs

    reflex move when  :target != nil{
    do goto     target:target on: road_system;
    if (location      =target) {
         target       <- nil;
    } 
}
	
	
   
    aspect PerSonAtt{
    draw sphere (5) color: is_hilled ? #orange : #red;
       }
    
} 
  
  
// les agents medecins interviendront pour guerrir les personnes contaminees

species name:Medecins skills:[moving,fipa] {
	
	
	Batiment my_home;
	Batiment Hp_center        <- Batiment(#pink);
	bool inside_health_center  <- false;
    float height               <- 0.5 + rnd(0.5);
    float curate_ratio;   // Capacite du Medecins de traiter les gens
    list l;
	bool is_contamines        <- false;
	bool is_immuniser         <- true; // booleen pour gerer l'immunisation du medecin face a l'epidemie
	bool is_hilled            <- false;
	point target;
	//Reflex for agent Medecins to become resistant
	
    reflex resistant when: (is_contamines and flip(0.05)) {
                            is_immuniser <- true;
    
    }
    
    // Reflex for agent Medecins to treat infected people depending on their desease level
    
    reflex traitement { 
    	     ask PerAtteintes    at_distance 5.25 #m{
         	self.is_hilled <- true;
    	    rgb color       <- rgb(#orange);
          }
        }

 reflex stay when:                  target = nil {
 if flip                            (inside_health_center ? 0.01 : 0.1) {
 Batiment bd_target                 <- inside_health_center ? one_of(Batiment) : Hp_center;
            target                  <- any_location_in (bd_target);
            inside_health_center    <- not inside_health_center;
         }
       } 
   
//   reflex move

    reflex move when: target != nil{
    do goto   target:target on: road_system;
    if (location    = target) {
        target      <- nil;
    } 
  }

    aspect medecin_form{
    draw sphere (6)  color: rgb(#blue) ;
     }
   }




species name: Batiment{
float height <- 10.2+ rnd(15);
	
	aspect Batiment {
	draw shape color: rgb( #orange) depth: height;
    }
  }


species name: Roads{
        geometry display_shape    <- line(shape.points);
	    float capacity            <- 1 + shape.perimeter/22;     //capacity of the road, usig it perimeter
	    int nb_personnes          <- 0 update: length(PerCorrectes at_distance 1);   //Number of people on the road
	    float speed_coeff         <- 1.0 update:  exp(-nb_personnes/capacity) min: 0.1;

    aspect Roads {
    draw shape color: rgb(#orange)  ;
    }
    
  }

// les agents Hopitaux recoivent les malades dans certains cas.
    species name: HopitalMirebalais skills:[communicating]{
 	int           max_capacity;  
 	rgb color     <- rgb(#red);
 	
 	aspect HopitalMirebalais{
    float height <- 3.2+ rnd(15);
 		draw shape  depth: height;
 	}
 	
 	
 	reflex alert when: nb_contamines = 100.0
        {
       write "Portail fermé !! Capacité dépassée";
        }
        
      reflex Door_Closed when: max_capacity = 500
        {
       write "Alerte rouge !!  Plus de médecins nécessaires";
        }
      }



experiment Epidemie type:gui{
   //  parameter "Nb d'PerCorrectes contamines" var: nb_contamines_init min: 25 max: 500;
        output {
         
        

        display Diagram_Observation  refresh_every:10 {  // Insertion d'un diagrame nous permettant de suivre l'evolution de l'epidemie 
                chart "Propagation de l'Epidemie" type: series  color: rgb(#red){
                data  "Vulnerable"               value:           nb_PerCorrectes_en_sont_pas_contamines    color: #blue;
                data  "Contamination"            value:           nb_PerCorrectes_pas_contamines            color: #orange;
                data  "Medecins"                 value:           nb_Medecin                                color: #blue;
            }
        }
        
        display Simulator_View type: opengl{
      
            species PerCorrectes            aspect: PerCorrectes ; 
            species Medecins                aspect: medecin_form;
            species Batiment                aspect: Batiment;
            species Roads                   aspect: Roads ;
            species HopitalMirebalais       aspect: HopitalMirebalais;
            species PerAtteintes            aspect: PerSonAtt;
                 
        }
        
        
         monitor "contamines PerCorrectes rate:"  value: Ratio_Contamines;
         monitor "Number of infected people:"     value: nb_contamines ;
        
    }
}
