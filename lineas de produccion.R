##ver tiempos por modelos para crear/asignar familias

limpia <- function(deptos.usar = c("CORTE","CORTE Y PREPARA","FAMILIA")){
     #convierte los datos del formato perugia al formato que se requiere para el 
     #algoritmo de la pagina web
     
     library(dplyr)
     library(ggplot2)
     library(gtools)
     library(cluster)
     library(gridExtra)
     library(tidyr)
     
      clas.tiempos <- c("factor", #linea
                       "character", #estilo
                       "integer", #pares
                       "factor", #fampespunte
                       "factor", #fammontado
                       "factor", #depto
                       "character", #funcion
                       "numeric", #tiempo
                       "numeric", #personas
                       "numeric") #meta
     
     tbtiempos <- tbl_df(read.csv("tiempos.csv", 
                                  colClasses = clas.tiempos,  
                                  stringsAsFactors = F))
     
     #sin filtrar deptos
     datos <- tbtiempos%>%
          select("ESTILO" = VCESTIL, DEPTO, FUNCION, TIEMPO, PERSONAS, META, LINEA)%>%
          mutate("FUNCIONCOMUN" = FUNCION)%>%
          mutate("DEPTO.GRAL" = ifelse(DEPTO %in% deptos.usar,"PESPUNTE",paste0(DEPTO)))%>%
          filter(DEPTO.GRAL == "PESPUNTE")%>%
          filter(TIEMPO > 0)
     
     
     estilos <- data.frame("ESTILO" = unique(datos$ESTILO))
     estilos$estilo.fake <- as.factor(seq(1:dim(estilos)[1]))
     
     tiempos.temp <- merge(datos, estilos, by = "ESTILO")

     #FUNCION COMúN - A,B,C PESPUNTADORES
     tiempos.temp$FUNCIONCOMUN[grep("A-PES|B-PES|C-PES|CA-PES", tiempos.temp$FUNCION)] = "PESPUNTADOR"
     tiempos.temp$FUNCIONCOMUN[grep("A-PRE|B-PRE|C-PRE|CA-PRE", tiempos.temp$FUNCION)] = "PRELIMINAR"
     tiempos.temp$FUNCIONCOMUN[grep("CORTADOR PIEL|CORTADOR FLASH|CA-COR", tiempos.temp$FUNCION)] = "CORTADOR CLICKEN"
     tiempos.temp$FUNCIONCOMUN[grep("CA-REB|REBAJADOR", tiempos.temp$FUNCION)] = "REBAJADOR"
     tiempos.temp$FUNCIONCOMUN[grep("CA-DOB", tiempos.temp$FUNCION)] = "DOBLILLADOR"
     tiempos.temp$FUNCIONCOMUN[grep("COMODIN", tiempos.temp$FUNCION)] = "PRELIMINAR"
     tiempos.temp$FUNCIONCOMUN[grep("CORTADOR FORRO", tiempos.temp$FUNCION)] = "CORTADOR PUENTE"
     
     tiempos <<- tiempos.temp%>%
          filter(!is.na(estilo.fake) & DEPTO.GRAL == "PESPUNTE")%>%
          group_by(estilo.fake, FUNCIONCOMUN)%>%
          summarise("SEGUNDOS.POR.PAR" = sum(TIEMPO))%>%
          select("ESTILO" = estilo.fake, "PUESTO" = FUNCIONCOMUN, SEGUNDOS.POR.PAR)
     
     tiempos.ren <<- tiempos
     write.csv(tiempos.ren,"Tiempos en renglones.csv",row.names = F)
     write.csv(tiempos.ren,"tiempos.final.csv",row.names = F)
     tiempos.col <<- spread(data = tiempos, key = PUESTO, value = SEGUNDOS.POR.PAR)
     write.csv(tiempos.col,"Tiempos en columnas.csv",row.names = F)
        
}

prueba <- function(...){
     for (i in familias){
          agrup.familias(familias = i)
     }
}


agrup.familias <- function(familias = 4,PESP.ON.PREL = 2,
                           planta = "LEON", view.not.found = F,
                           coleccion = c("OTIN16","PRVE17"), usar.demanda = T, 
                           file.demanda = "demanda.csv") {
     familias <<- familias
     #grafica quantiles de pespuntadores, doblillador y prelimnares
     sd.plot <<- tiempos%>%
          filter(DEPTO == "FAMILIA" & FUNCIONCOMUN %in% c("PESPUNTADOR","PRELIMINAR",
                                                          "C-PESPUNTADOR","C-PRELIMINAR",
                                                          "DOBLILLADOR"))
     ggplot(data = sd.plot,aes(FUNCIONCOMUN,PERSONAS)) + geom_boxplot() +
          theme(axis.text.x = element_text(angle = 45, hjust = 1, size = 10))
     
     #elimina funciones de cantera
     ifelse(planta == "LEON",
            estilos <-  tiempos[-grep("CA-", tiempos$FUNCIONCOMUN),],
            estilos <-  tiempos[grep("CA-", tiempos$FUNCIONCOMUN),])

     
     if(usar.demanda == F){
          totpers <- estilos%>%
               filter(DEPTO %in% "FAMILIA", COLECC %in% coleccion)%>%
               select(ESTILO, PERSONAS)%>%
               group_by(ESTILO)%>%
               summarise(PERSONAS = sum(PERSONAS))
          
          critico <- estilos%>%
               filter(DEPTO %in% "FAMILIA", COLECC %in% coleccion, 
                      FUNCIONCOMUN == "PESPUNTADOR" | FUNCIONCOMUN == "PRELIMINAR")%>%
               select(ESTILO, COLECC, FUNCIONCOMUN, PERSONAS)%>%
               group_by(ESTILO, COLECC, FUNCIONCOMUN)%>%
               summarise(PERSONAS = sum(PERSONAS))
     } else {
          estilos_dem <- data.frame(read.csv(file.demanda, na.strings = c("#N/A","")))
          estilos_dem <<- estilos_dem%>%select(ESTILO, CLIENTE, PARES.VENTA, PRONO,
                                               COLECC, CORTE, FAM.ASIG)
          #total personas por estilo
          totpers <- estilos%>%
               filter(DEPTO %in% "FAMILIA", ESTILO %in% estilos_dem$ESTILO)%>%
               select(ESTILO, PERSONAS)%>%
               group_by(ESTILO)%>%
               summarise("TOT.PERSONAS" = sum(PERSONAS))
          
          critico <- estilos%>%
               filter(DEPTO %in% "FAMILIA", ESTILO %in% estilos_dem$ESTILO)%>%
               select(ESTILO, COLECC, FUNCIONCOMUN, PERSONAS)%>%
               group_by(ESTILO, COLECC, FUNCIONCOMUN)%>%
               summarise(PERSONAS = sum(PERSONAS))
          
          print(paste("Encontrados: Tiempos:",
                      length(unique(critico$ESTILO)), "Demanda:",
                      length(estilos_dem$ESTILO), "Porcentaje:",
                      ceiling(length(unique(critico$ESTILO))/length(estilos_dem$ESTILO)*100),"%"))
          notfound <- merge(estilos_dem, totpers, all.x = T)
          if (view.not.found == T) print(notfound[is.na(notfound$TOT.PERSONAS),])
     }
     
     
     p.plot <- spread(critico, FUNCIONCOMUN, PERSONAS)%>%
          mutate("R.PESP" = round(PESPUNTADOR,0),"R.PREL" = round(PRELIMINAR,0))
     qplot(data = p.plot, x= R.PESP, y=R.PREL) + 
          geom_point(col = "green", alpha = 0.3) +
          stat_smooth(method = "lm")
     
     
     #agrupando modelos con k mean y clusters y dandole m?s valor a pespuntadores
     #que a preliminares 2:1
     a <- spread(critico, FUNCIONCOMUN, PERSONAS)
     a1 <- merge(a, totpers, by= "ESTILO")
     a1$id = seq(1:nrow(a))
     p.clust <<- a1%>%
          mutate("PESP.POND" = PESPUNTADOR * PESP.ON.PREL)%>%
          select(id, ESTILO, COLECC, PESPUNTADOR, PESP.POND, PRELIMINAR, TOT.PERSONAS)

     #kmeans analisis
     set.seed(0)
     k <<- kmeans(scale(p.clust[,4:6]), familias, nstart = 10, iter.max = 100)
     
     
     #plot
     clusplot(p.clust, k$cluster, main = "Agrupacion de estilos en familias",
              color = T, labels = 1, lines = 0)
     p.clust$FAMILIA <- k$cluster

     
     #por medio de hclust
     Pesp.Prel.Tot <- dist(scale(p.clust%>%select(PESPUNTADOR, PRELIMINAR, TOT.PERSONAS)))
     clusters <- hclust(Pesp.Prel.Tot)
     plot3 <- plot(clusters)
     famcluster <- cutree(clusters, k = familias)
     
     p.clust$FAMh <- famcluster
     p.clust <<- p.clust
     
     #ver asignaciones en pespuntador vs preliminar
     plot1 <- ggplot(data = p.clust, aes(PESPUNTADOR, PRELIMINAR)) + 
          geom_point(aes(colour = factor(FAMILIA), size = TOT.PERSONAS, alpha = 0.5))+
          ggtitle("Asignacion por K-Means")
     
     #convertir columnas en funcion comun
     plot.clust <<- gather(p.clust, "FUNCIONCOMUN", "PERSONAS",c(PRELIMINAR, PESPUNTADOR, TOT.PERSONAS))
     
     ##revisar visualmente la asignacion por kmeans
     plot2 <- ggplot(data = plot.clust, aes(ESTILO, PERSONAS)) +
          geom_point(aes(colour = factor(FAMILIA), alpha = 0.5)) +
          facet_grid(FUNCIONCOMUN~., scales = "free") +
          theme(axis.text.x = element_text(angle = 45, hjust = 1, size = 8),
                strip.text.y = element_text(size = 6),
                panel.grid.major = element_line(colour = "darkgrey",
                                                linetype = "dotted"))
     grid.arrange(plot1, plot2, nrow = 2, ncol=1)
     
     #print dendogram
     print(plot3)

      #ver asignaciones en pespuntador vs preliminar
     plot4 <- ggplot(data = p.clust, aes(PESPUNTADOR, PRELIMINAR)) + 
          geom_point(aes(colour = factor(FAMh), size = TOT.PERSONAS, alpha = 0.5,
                         main = "Familias por m?todo de clustering")) +
          ggtitle("Asignacion por clusters")
     ##revisar visualmente la asignacion por clusters
     plot5 <- ggplot(data = plot.clust, aes(ESTILO, PERSONAS)) +
          geom_point(aes(colour = factor(FAMh), alpha = 0.5)) +
          facet_grid(FUNCIONCOMUN~., scales = "free") +
          theme(axis.text.x = element_text(angle = 45, hjust = 1, size = 8),
                strip.text.y = element_text(size = 6),
                panel.grid.major = element_line(colour = "darkgrey",
                                                linetype = "dotted"))
     grid.arrange(plot4, plot5, nrow = 2, ncol=1)
     
     
     #comparativa
     result <- rbind(plot.clust%>%
          group_by(FAMILIA, FUNCIONCOMUN)%>%
          summarise("avg" = mean(PERSONAS), "sd" = sd(PERSONAS))%>%
          mutate("SIM"= "K.MEANS"),
          plot.clust%>%
          group_by("FAMILIA" = FAMh, FUNCIONCOMUN)%>%
          summarise("avg" = mean(PERSONAS), "sd" = sd(PERSONAS))%>%
          mutate("SIM"= "H.CLUST"))
     
     View(data.frame(result%>%group_by(SIM, FUNCIONCOMUN, FAMILIA)%>%summarise("promedio" = mean(avg)),
             result%>%group_by(SIM, FUNCIONCOMUN, FAMILIA)%>%summarise("sd" = mean(sd)))%>%
                select(SIM, FUNCIONCOMUN, FAMILIA, promedio, sd)%>%
                mutate("%-sd" = round((sd/promedio)*100,0))%>%
               arrange(FAMILIA, SIM, FUNCIONCOMUN),"Analisis")
     
}

reportar.familias <- function(){
     
     #asignar mayor a menor gente para fam 1 a 4
     orden.k <- plot.clust%>%
          group_by(FAMILIA)%>%
          summarise("mean.k" = mean(PERSONAS))%>%
          arrange(mean.k)%>%
          mutate("FAM.K"= seq(1:familias))%>%
          select(FAMILIA,FAM.K)
     orden.h <- plot.clust%>%     
          group_by(FAMh)%>%
          summarise("mean.h" = mean(PERSONAS))%>%
          arrange(mean.h)%>%
          mutate("FAM.H"= seq(1:familias))%>%
          select(FAMh, FAM.H)
     
     temp <- merge(plot.clust, orden.k, by = "FAMILIA")%>%
          group_by(ESTILO)%>%
          arrange(FAM.K)
     temp2 <- merge(temp, orden.h, by = "FAMh") %>%
          group_by(ESTILO)%>%
          arrange(FAM.K)
          
     result <- unique(temp2[,c(4,9:10)])
     temp <- merge(estilos_dem, result, by = "ESTILO", all.x = T)
     demanda <<- temp%>%
          select(ESTILO, CLIENTE, PARES.VENTA, PRONO, 
                 COLECC, FAM.ASIG, FAM.K, FAM.H)%>%
          arrange(FAM.K, ESTILO)
     View(demanda, "Asignacion familias")
     message("Enviado resultado a: demanda_con_familias.csv")
     write.csv(demanda, "demanda_con_familias.csv", row.names = F)
     
     paresxfamK <- demanda%>%
          group_by(FAM.K)%>%
          summarise("PARES"= sum(PRONO))
     print(paresxfamK)
     paresxfamH<- demanda%>%
          group_by(FAM.H)%>%
          summarise("PARES"= sum(PRONO))
     print(paresxfamH)
}




#graficar
grafica.depto <- function(depto = "FAMILIA", planta = "LEON", 
                          coleccion = c("OTIN16","PRVE17"), 
                          agrupa.pesp = TRUE) {
     #elimina funciones de cantera
     ifelse(planta == "LEON",
            estilos <-  tiempos[-grep("CA-", tiempos$FUNCIONCOMUN),],
            estilos <-  tiempos[grep("CA-", tiempos$FUNCIONCOMUN),])
     
     estilos <- estilos%>%
          filter(DEPTO %in% depto, COLECC %in% coleccion)%>%
          arrange(DEPTO)
     
     if(agrupa.pesp == TRUE){
          #plot data
          p <- ggplot(data = estilos, aes(ESTILO, PERSONAS)) +
               geom_point(aes(colour = DEPTO)) +
               facet_grid(FUNCIONCOMUN~., scales = "free")
          
          #format plot
          plot1 <- p + theme(axis.text.x = element_text(angle = 45, hjust = 1, size = 8),
                             strip.text.y = element_text(size = 6), 
                             panel.grid.major = element_line(colour = "darkgrey", 
                                                             linetype = "dotted")) + 
               labs(colour = "DEPTO")
     } else {
          p <- ggplot(data = estilos, aes(ESTILO, PERSONAS)) +
               scale_color_brewer(palette = "Set1") +
               geom_point(aes(colour = DEPTO)) +
               facet_grid(FUNCION~., scales = "free")
          #format plot
          plot1 <- p +
               theme(axis.text.x = element_text(angle = 45, hjust = 1, size = 8),
                     strip.text.y = element_text(size = 6),
                     panel.grid.major = element_line(colour = "darkgrey",
                                                     linetype = "dotted"))
     }
     print(plot1)
}
